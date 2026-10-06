# AI and persistence

The application layer supports one human and one, two, or three computer opponents independently of the game UI. `GameSession` owns the engine, automatic progression, random streams, and local checkpoint. It has no SwiftUI dependency. One caller must serialize access to a session and own its save file; concurrent sessions must not write the same file. The app uses the actor-owned adapter described in [App presentation](AppPresentation.md).

## Match configuration

`BotCount` admits only `.one`, `.two`, and `.three`, for two through four total participants. Pass it to `GameSession.startNewMatch(botCount:)` or `SessionDriver.newMatch(botCount:)`. Both default to `.two`; the shipping New Game path still creates the V1 configuration and does not expose player selection yet.

New matches always seat the human at ID zero, followed by bots with IDs one through the configured count. This order is deterministic and retains eliminated seats. The engine already deals four cards per active player and handles turn order and response queues without a fixed seat count. Every non-human actor uses the same V1 strategy. `GameSession.botCount` describes the original configuration, not the number of bots still active.

## Bot boundary and decisions

`BotStrategy.chooseAction(from:using:)` accepts a `PlayerView` and an injected decision generator. It returns an optional `GameAction`, with no actor identity or engine mutation. An out-of-turn view produces no action. `GameSession` obtains the expected actor from the authoritative phase, creates that seat's view, checks the returned action against its legal actions, and submits it through `GameEngine.apply(_:by:)` for validation.

`PlayerView` contains only the bot's hand and public facts: seats, strokes, participation, hand counts, stake, tricks, knocks, and legal actions. It carries no authoritative state, opponent hands, undealt cards, or deal generator. Hidden-card permutations are tested both before play and after public actions. Deck and bot randomness use independent `SeededRandom` streams; only the decision stream crosses the strategy boundary.

`V1BotStrategy` uses a small set of heuristics:

- Play only advertised legal cards, so following suit stays an engine rule.
- Spend low cards early. On trick three, try to win the lead when another useful high card remains. On trick four, prefer a card that currently wins; use the cheapest winner if last to play, otherwise the strongest.
- Estimate strength by counting higher cards of the same suit not yet known from the bot's hand or public plays. Unseen cards might be undealt; the bot never assigns exact hands to opponents.
- Knock more frequently in strong positions, occasionally in moderately promising ones. This is the only randomized decision in V1.
- Hold when estimated strength justifies the stake, with a higher threshold at higher stakes. If passing itself eliminates the bot, prefer Hold when the strength estimate is positive. A weak estimate favors Pass; it does not prove that no theoretical winning chance remains.

This is intentionally imperfect play. Tests inject seeds or fixed draws; production obtains separate seeds from the system generator. Saved generator states allow exact continuation in the current implementation. Cross-toolchain fixture tests should retain explicit decks because Swift's shuffle algorithm is not a save-format guarantee.

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

New `SavedSession` values also encode an integer `botCount`. The envelope remains version 1: this additive field can be decoded without migrating the authoritative state or random streams. A missing field means the historical two-bot configuration, never an inferred count. An explicit null or unsupported count is corrupt; a supported count that disagrees with the retained match seats is invalid. The human must still be a seated player. Eliminated seats continue to count toward the original configuration. Historical V1 saves load without rewriting or recounting them; the next successful transaction writes the explicit count. Older V1 binaries retain their three-seat validation and reject new two- or four-seat saves safely.

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

Non-UI tests cover legal bot actions, deterministic tactics and full matches, hidden-information boundaries, ordered responses, human pauses, exact restored continuation, human-scoped statistics, resets, winner/draw outcomes, corruption, and file operations. Session, driver, and bot playouts cover all three bot counts. Two-seat scenarios verify that a lone opponent's Pass immediately ends the round, taking precedence over any committed trick winner. Rollback tests exercise deals and their random stream, terminal scoring, a later failure within automatic progression, resets, changing the configured count on new-match replacement, and an unwritable existing save. Existing engine playout tests restore every intermediate state across two, three, four, and eight seats.

`TuppenTests/Fixtures/version-1-pending-knock.json` is a fixed compatibility fixture without a player-count field: an ordered first deal with Bob's Knock, Charlie's Hold, and Alice's response pending. Maintain it independently of the encoder so schema changes cannot hide behind round-trip tests. There are no automated UI tests.
