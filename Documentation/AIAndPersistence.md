# AI and persistence

The application layer supports one human and one, two, or three computer opponents independently of the game UI. `GameSession` owns the engine, automatic progression, random streams, and local checkpoint. It has no SwiftUI dependency. One caller must serialize access to a session and own its save file; concurrent sessions must not write the same file. The app uses the actor-owned adapter described in [App presentation](AppPresentation.md).

## Match configuration

`BotCount` admits only `.one`, `.two`, and `.three`, for two through four total participants. `BotDifficulty` admits only `.easy`, `.medium`, and `.hard`. Pass both to `GameSession.startNewMatch(botCount:difficulty:)` or `SessionDriver.newMatch(botCount:difficulty:)`. Defaults are `.two` and `.medium`. New Game selects both per match; Continue uses the saved configuration independently of the drafts.

New matches always seat the human at ID zero, followed by bots with IDs one through the configured count. This order is deterministic and retains eliminated seats. The engine already deals four cards per active player and handles turn order and response queues without a fixed seat count. Every non-human actor uses the same selected difficulty. `GameSession.botCount` describes the original configuration, not the number of bots still active; `difficulty` remains fixed for the match.

## Bot boundary and decisions

`BotStrategy.chooseAction(from:using:)` accepts a `PlayerView` and an injected decision generator. It returns an optional `GameAction`, with no actor identity or engine mutation. An out-of-turn view produces no action. `GameSession` obtains the expected actor from the authoritative phase, creates that seat's view, checks the returned action against its legal actions, and submits it through `GameEngine.apply(_:by:)` for validation.

`PlayerView` contains only the bot's hand and public facts: seats, strokes, participation, hand counts, stake, tricks, knocks, and legal actions. It carries no authoritative state, opponent hands, undealt cards, or deal generator. Hidden-card permutations are tested both before play and after public actions. Deck and bot randomness use independent `SeededRandom` streams; only the decision stream crosses the strategy boundary.

`BotDifficulty.makeStrategy()` maps Easy to `EasyBotStrategy`, Medium to the unchanged `V1BotStrategy`, and Hard to `HardBotStrategy`. The session resolves this from the checkpoint for every automatic decision. Explicit strategy injection remains available for deterministic test scenarios; ordinary driver calls never override the saved choice.

Medium uses the original V1 heuristics:

- Play only advertised legal cards, so following suit stays an engine rule.
- Spend low cards early. On trick three, try to win the lead when another useful high card remains. On trick four, prefer a card that currently wins; use the cheapest winner if last to play, otherwise the strongest.
- Estimate strength by counting higher cards of the same suit not yet known from the bot's hand or public plays. Unseen cards might be undealt; the bot never assigns exact hands to opponents.
- Knock more frequently in strong positions, occasionally in moderately promising ones. This is the only randomized decision in V1.
- Hold when estimated strength justifies the stake, with a higher threshold at higher stakes. If passing itself eliminates the bot, prefer Hold when the strength estimate is positive. A weak estimate favors Pass; it does not prove that no theoretical winning chance remains.

Easy evaluates raw rank, without counting unseen cards or inferring missing suits. It chooses between the two weakest legal cards in early tricks, sometimes surrendering useful lead control, and takes an available winner on the fourth. It rarely Knocks, requiring a strong raw rank and a low stake. Its simple Hold threshold grows with the stake; an eliminating Pass is avoided when its estimate still allows a win.

Hard counts unseen higher cards and records proven void suits: an off-suit play proves that seat could not follow the lead, and cards never return to a hand during a round. Public hand counts and void suits narrow potential threats. Its survival estimate assumes roughly uniform unseen possibilities; it does not assign exact hands, and undealt cards remain unknown. Earlier active opponents' Knocks and Holds modestly reduce confidence rather than prove strength. Passed seats stop contributing future threats, while their committed cards still affect the current winner and next leader.

Hard conserves established cards in early tricks and weighs winning the third-trick lead against the strength of its retained fourth card. In the fourth trick, a visibly beaten committed card has no winning chance; a currently winning card still faces opponents yet to play. Knock thresholds account for stake and whether the raise creates elimination risk. Hold compares the raised loss with the cheaper Pass penalty, favors a survivable Pass when losing would eliminate the bot, and avoids a certain eliminating Pass when a chance remains.

The strategies can intentionally agree, especially on forced-suit single-card turns and visibly lost final tricks. Hard reasons more deeply from public history but remains a bounded heuristic, not an optimal solver. Difficulty affects neither information access nor rule validation.

Tests inject seeds or fixed draws; production obtains separate seeds from the system generator when creating a match. All strategy randomness uses the existing saved decision stream. Saved generator states allow exact continuation in the current implementation. Cross-toolchain fixture tests should retain explicit decks because Swift's shuffle algorithm is not a save-format guarantee.

## Session orchestration

```swift
let store = try LocalGameStore.applicationSupport()
let session = try GameSession(store: store)
if !session.hasActiveMatch {
    try session.startNewMatch()
}
let progress = try session.advanceBots()
// On humanInput, obtain session.humanView() and submit a chosen legal action.
// On yielded, schedule another call. On matchFinished, present the result.
```

`advanceOneAutomaticStep` applies one bot action or deals the next round. During a knock it follows `PendingKnock.expectedResponder`, stopping before the human's response. Once responses finish, the engine resumes the knocker's mandatory card turn. A human who has passed or been eliminated does not block the remaining bots.

`advanceBots` repeats those steps until human input, match completion, or a cooperative action budget (64 by default). `yielded` means the caller should resume; it imposes no limit on a valid match. There are no timers or artificial delays. The app uses the single-step method to publish each committed state and pause at round results.

Every successful action and between-round deal saves automatically. The session first prepares a candidate engine, counters, and random streams, then writes the checkpoint, then publishes the new live state and events. A failed write discards that candidate, including consumed randomness, so retrying is safe. In a multi-step call, earlier successful steps remain committed if a later step fails; read the current session state or use the single-step API when presenting individual events.

## Save format and recovery

`LocalGameStore` uses Foundation to atomically replace `Application Support/Tuppen/game.json`. `GameStore` permits isolated in-memory or temporary-file tests. The JSON envelope has `version: 1` and a `game` payload containing `LocalStatistics` plus an optional `SavedSession`. The latter stores the human identity, authoritative `MatchState`, and both random generator states. There is no presentation state.

Statistics and match state are separate types in the same atomic file. Saving them independently could leave a counted outcome paired with its pre-outcome match after termination. Terminal checkpoints are retained, but `hasActiveMatch` is false. Starting a new match replaces the previous match and retains lifetime counters; abandoning a match does not invent completion events.

New `SavedSession` values also encode an integer `botCount` and a string `difficulty` (`easy`, `medium`, or `hard`). The envelope remains version 1: these additive fields need no migration of authoritative state or random streams. An absent count means the historical two-bot configuration, never an inferred count; absent difficulty means Medium, the historical V1 strategy. Explicit nulls or unsupported values are corrupt. A supported count that disagrees with retained match seats is invalid, and the human must still be seated. Eliminated seats count toward the original configuration. Historical saves load without rewriting or recounting them; the next successful transaction writes both fields. Older V1 binaries reject new two- or four-seat saves through their three-seat validation. Builds predating difficulty selection ignore the new field and use their original strategy, so downgrades do not preserve Easy or Hard behavior.

The codec reads the version before interpreting the payload. Unknown versions produce `unsupportedVersion`; malformed data produces `corruptData`; inconsistent decoded contents produce `invalidContents`. Read/write failures also have typed errors. These carry no UI text and can be mapped to Apple's string catalog by presentation code. A missing file means a new local profile.

`GameEngine(restoring:)` validates card conservation and bounded structure, reconstructs the start of the saved round, and checks that its recorded plays and knocks reproduce the exact snapshot through existing rule validation. This handles pending responses, passed committed cards, elimination, and draws without duplicating scoring rules. Earlier completed rounds must also be supported by prior scoring progress: each costs at least one unit, with each player's strokes capped at seven for this check. Current-round penalties are excluded. A fresh zero-stroke game claiming round 21 is therefore rejected at load time. This is a necessary consistency check, not full historical replay; restoration emits no application events or reconstructed statistics. Phase 1 rules are unchanged.

A failed load leaves the file untouched. The app reports a localized error and offers a new game using `GameSession.empty(store:)`. Creating the empty session alone does not overwrite anything; only a successful new-match save replaces the file. `LocalGameStore.remove()` also remains available for explicit recovery. Compatible migrations belong at the codec's version switch when needed; changes to the persisted schema or restoration semantics require an explicit compatibility decision and a version bump where necessary.

## Human statistics

| Counter | Recorded fact |
| --- | --- |
| Matches played | Match reaches a winner or draw, even if the human was eliminated earlier. |
| Matches won | Human is the match winner; a draw is not a win. |
| Rounds played | A round the human was dealt into reaches a terminal outcome. It still counts after the human Passes or is eliminated during it. Later bot-only rounds do not count. |
| Rounds won | Human is the active round winner. A passed card winning with `noActiveWinner` does not count. |
| Knocks made / held / passed | Successful human Knock / Hold / Pass actions only. |
| Highest stake reached | Maximum authoritative stake observed during accepted transitions while the human participates, including their Pass action. It freezes once the human leaves that round and excludes later bot-only raises. |

Round participation comes from retained hand entries, which remain present even when a dealt player has no cards left, Passes, or is eliminated. Current participation and the human's Pass event define the stake boundary: passing at stake two followed by bot raises to three leaves the human maximum at two.

Counters consume only newly accepted engine events during a checkpoint commit. Restoration loads them directly and produces no historical events, so opening a finished round or terminal match cannot recount it. Failed or illegal actions do not count.

`resetStatistics()` atomically zeros every counter without changing the match. Only subsequent accepted transitions contribute; if the human is still participating, the next transition observes that round's current stake. Reset after Pass does not recover the earlier stake. Reset after elimination followed by bot-only match completion legitimately yields one match played and zero rounds played. Validation therefore allows matches played to exceed rounds played, and never requires the human's highest stake to cover the current round's stake, even for a just-reset participating human.

## Verification

Non-UI tests cover legal bot actions, deterministic tactics and full matches, hidden-information boundaries, ordered responses, human pauses, exact restored continuation, human-scoped statistics, resets, winner/draw outcomes, corruption, and file operations. Configuration and complete-match tests cover all nine count/difficulty combinations. Tests compare Medium with V1, restore each difficulty during partial tricks and pending responses, and check Skip to Result against ordinary progression. Two-seat scenarios verify that a lone opponent's Pass immediately ends the round, taking precedence over any committed trick winner. Rollback tests exercise deals and their random stream, terminal scoring, a later failure within automatic progression, resets, changing configuration on new-match replacement, and an unwritable existing save. Existing engine playout tests restore every intermediate state across two, three, four, and eight seats.

`TuppenTests/Fixtures/version-1-pending-knock.json` is a fixed compatibility fixture without count or difficulty fields: an ordered first deal with Bob's Knock, Charlie's Hold, and Alice's response pending. Maintain it independently of the encoder so schema changes cannot hide behind round-trip tests. There are no automated UI tests.
