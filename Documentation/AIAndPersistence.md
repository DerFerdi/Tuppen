# AI and persistence

The application layer supports one human and one, two, or three computer opponents independently of the game UI. `GameSession` owns the engine, automatic progression, random streams, and local checkpoint. It has no SwiftUI dependency. One caller must serialize access to a session and own its save file; concurrent sessions must not write the same file. The app uses the actor-owned adapter described in [App presentation](AppPresentation.md).

## Match configuration

`BotCount` admits only `.one`, `.two`, and `.three`, for two through four total participants. `BotDifficulty` admits only `.easy`, `.medium`, and `.hard`. Pass both to `GameSession.startNewMatch(botCount:difficulty:)` or `SessionDriver.newMatch(botCount:difficulty:)`. Defaults are `.two` and `.medium`. New Game selects both per match; Continue uses the saved configuration independently of the drafts.

Both creation methods also accept `houseRules: HouseRules`, defaulting to `.standard`. This immutable domain configuration is independent of count and difficulty. The New Game sheet passes the confirmed rules together with count and difficulty; Continue reads the saved configuration. Presentation details are covered in [App presentation](AppPresentation.md#house-rules).

New matches always seat the human at ID zero, followed by bots with IDs one through the configured count. This order is deterministic and retains eliminated seats. The engine already deals four cards per active player and handles turn order and response queues without a fixed seat count. Every non-human actor uses the same selected difficulty. `GameSession.botCount` describes the original configuration, not the number of bots still active; `difficulty` remains fixed for the match.

## Bot boundary and decisions

`BotStrategy.chooseAction(from:using:)` accepts a `PlayerView` and an injected decision generator. It returns an optional `GameAction`, with no actor identity or engine mutation. An out-of-turn view produces no action. `GameSession` obtains the expected actor from the authoritative phase, creates that seat's view, checks the returned action against its legal actions, and submits it through `GameEngine.apply(_:by:)` for validation.

`PlayerView` contains only the bot's hand and public facts: seats, strokes, participation, hand counts, stake, tricks, Knocks, House Rules, challenge revelations, and legal actions. It carries no authoritative state, hidden opponent hands, undealt or unverified discarded cards, private replay journal, or deal generator. A challenge reveals the old hand only; replacement cards remain private. Hidden-card permutations are tested both before play and after public actions. Deck and bot randomness use independent `SeededRandom` streams; only the decision stream crosses the strategy boundary.

`BotDifficulty.makeStrategy()` maps Easy to `EasyBotStrategy`, Medium to `V1BotStrategy`, and Hard to `HardBotStrategy`. The session resolves this from the checkpoint for every automatic decision. Explicit strategy injection remains available for deterministic test scenarios; ordinary driver calls never override the saved choice.

Medium retains the V1 card-play and ordinary Hold heuristics:

- Play only advertised legal cards, so following suit stays an engine rule.
- Spend low cards early. On trick three, try to win the lead when another useful high card remains. On trick four, prefer a card that currently wins; use the cheapest winner if last to play, otherwise the strongest.
- Estimate strength by counting higher cards of the same suit not yet known from the bot's hand or public plays. Unseen cards might be undealt; the bot never assigns exact hands to opponents.
- Ordinary Knock uses one decision draw when confidence is at least 0.55: confidence below 0.85 now Knocks on 2 of 100 draws, reduced from 8; confidence at least 0.85 retains 65 of 100. Speculative raises remain possible without changing draw eligibility or consumption. Four Pictures bluffing is a separate decision.
- Hold when estimated strength justifies the stake, with a higher threshold at higher stakes. If passing itself eliminates the bot, prefer Hold when the strength estimate is positive. A weak estimate favors Pass; it does not prove that no theoretical winning chance remains.

Easy evaluates raw rank, without counting unseen cards or inferring missing suits. It chooses between the two weakest legal cards in early tricks, sometimes surrendering useful lead control, and takes an available winner on the fourth. It rarely Knocks, requiring a strong raw rank and a low stake. Its simple Hold threshold grows with the stake; an eliminating Pass is avoided when its estimate still allows a win.

Hard counts unseen higher cards and records proven void suits: an off-suit play proves that seat could not follow the lead, and cards never return to a hand during a round. Public hand counts and void suits narrow potential threats. Its survival estimate assumes roughly uniform unseen possibilities; it does not assign exact hands, and undealt cards remain unknown. Earlier active opponents' Knocks and Holds modestly reduce confidence rather than prove strength. Passed seats stop contributing future threats, while their committed cards still affect the current winner and next leader.

Hard conserves established cards in early tricks and weighs winning the third-trick lead against the strength of its retained fourth card. In the fourth trick, a visibly beaten committed card has no winning chance; a currently winning card still faces opponents yet to play. Knock thresholds account for stake and whether the raise creates elimination risk. Hold compares the raised loss with the cheaper Pass penalty, favors a survivable Pass when losing would eliminate the bot, and avoids a certain eliminating Pass when a chance remains.

The strategies can intentionally agree, especially on forced-suit single-card turns and visibly lost final tricks. Hard reasons more deeply from public history but remains a bounded heuristic, not an optimal solver. Difficulty affects neither information access nor rule validation.

### House Rules tactics

All three strategies handle every optional-rule decision directly. `BotDecisionSupport` shares expected-actor checks, legal-card ordering, and the decisive trick number; difficulty policies remain inside the strategies. The session has no special tactical fallback. The engine alone decides whether a restricted Knock or another claim is legal.

During Poverty, Easy compares raw hand strength with a conservative threshold. Medium uses its existing higher-card estimate. Both raise their Hold threshold when losing two strokes would eliminate them. Hard also weighs public hand counts, suit prospects, opening seat, and the pressure left by a one-stroke Pass. Every threshold uses the configured maximum of seven or ten. Poor participants receive no response choice; all-poor rounds proceed directly with cards.

Every difficulty claims truthful Four Pictures whenever legal, including repeated picture ranks and repeated exchanges. Each replacement is evaluated afresh; when no further exchange is chosen or legal, the bot Knocks or plays. Each successful exchange consumes four undealt cards, bounding repeated exchanges. Easy never makes a false claim. Medium considers only a weak hand containing one Seven and three low pictures, with room to absorb a challenge penalty and at most two challengers: it claims on 2 of 100 draws against one opponent or 1 against two. Hard requires those same safeguards, low estimated round prospects, and every opponent within two strokes of elimination. Its bluff thresholds are also 2 or 1 of 100. Both avoid repeating a lie already proved by their publicly retained hand. Hard also refuses a bluff when public cards already leave fewer than four pictures available to it; this check excludes its private hand.

All levels challenge a claim contradicted by known retained cards. Otherwise Easy declines. Medium makes a restrained 2-of-100 challenge, or 6-of-100 after a prior exposed bluff, only when its own and the claimant's stroke positions permit that risk. Hard normally declines without evidence; it can prove a false claim when public cards leave fewer than four pictures available, or cautiously challenge on 4 of 100 draws after a prior exposed bluff. A historical bluff remains only a weak behavioral signal after an exchange. Uncertain challenges are avoided near elimination; a publicly proven false claim carries no penalty risk for the challenger.

`PlayerView.knownHands` contains only publicly revealed cards still retained by their owner. `discardedPublicCards` contains only revealed cards subsequently removed by a public whole-hand exchange. The engine derives both from existing revelation, play, and exchange records without consulting current opponent hands. Hidden old hands and replacements never enter either field. Historical `revealedHands` remains available separately. Playing a known card removes it from retained knowledge; an exchange retires the entire old hand; a new round or tiebreak starts fresh. Medium can discount publicly discarded higher cards. Hard additionally treats known opposing higher cards as threats and removes known locations from its unseen-card estimate.

In the Eight-Card-Rule, all strategies use trick eight as decisive. Easy keeps its simple early discards and final winner preference. Medium conserves useful high cards and seeks lead control on trick seven. Hard also values a second potential control card during early play, infers void suits, and weighs the seventh-trick lead against its final retained card. Trick four has no special tactical scoring status in a tiebreak. These are bounded heuristics, not guarantees of optimal play.

With House Rules disabled, Easy and Hard retain their standard decisions. Medium's only standard policy change is the narrower speculative Knock threshold described above.

Tests inject seeds or fixed draws; production obtains separate seeds from the system generator when creating a match. All strategy randomness uses the existing saved decision stream. V4 claims and uncertain challenges consume this stream only when their tactical conditions permit a random choice. There is no strategy-local state or new persisted AI memory; public hand knowledge is rebuilt from the checkpoint. The random-stream representation is unchanged by the version-2 envelope described below. Restored continuation is deterministic within this implementation, although the intentional tactical changes can differ from an older binary’s future choices. Cross-toolchain fixture tests should retain explicit decks because Swift's shuffle algorithm is not a save-format guarantee.

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

`GameEngine.expectedActor` also covers Poverty responses, challenge decisions, and tiebreak turns. Automatic progression always stops before that actor is the human. An awaiting Eight-Card-Rule consumes the next deck shuffle as a saved deal step. Its participants may have terminal stroke totals from the last scored round; tiebreak participation, rather than those totals, determines who acts. The presentation driver keeps the existing result-acknowledgment boundary: `nextRound()` starts the pending tiebreak, while `advance()` performs its subsequent bot card turns.

`advanceBots` repeats those steps until human input, match completion, or a cooperative action budget (64 by default). `yielded` means the caller should resume; it imposes no limit on a valid match. There are no timers or artificial delays. The app uses the single-step method to publish each committed state and pause at round results.

Every successful action and between-round deal saves automatically. The session first prepares a candidate engine, counters, and random streams, then writes the checkpoint, then publishes the new live state and events. A failed write discards that candidate, including consumed randomness, so retrying is safe. In a multi-step call, earlier successful steps remain committed if a later step fails; read the current session state or use the single-step API when presenting individual events.

## Save format and recovery

`LocalGameStore` uses Foundation to atomically replace `Application Support/Tuppen/game.json`. `GameStore` permits isolated in-memory or temporary-file tests. Every new JSON envelope has `version: 2` and a `game` payload containing `LocalStatistics` plus an optional `SavedSession`. The latter stores the human identity, authoritative `MatchState`, both random generator states, an integer `botCount`, and a string `difficulty` (`easy`, `medium`, or `hard`). There is no presentation state.

Statistics and match state are separate types in the same atomic file. There is no independent statistics file or statistics writer in `UserDefaults`; only preferences use `UserDefaults`. Saving counters independently could leave a counted outcome paired with its pre-outcome match after termination. Terminal checkpoints are retained, but `hasActiveMatch` is false. Starting a new match replaces the previous match and retains lifetime counters; abandoning a match does not invent completion events. Version 2 applies even when House Rules are standard or the profile has no match, so previously accumulated House Rules counters remain behind the same version boundary.

The reader accepts historical version-1 checkpoints from V1 and V2–V4 development. Only absent historical fields receive defaults: two bots, Medium difficulty, seven maximum strokes, all optional House Rules off, empty optional-rule collections, and zero for new counters. Explicit valid saved values always win over those defaults; explicit nulls in nonoptional fields or unsupported values remain corrupt. A supported count that disagrees with retained match seats is invalid, and the human must still be seated. Eliminated seats count toward the original configuration.

Loading a historical checkpoint never rewrites it, advances randomness, or recounts events. The next successful checkpoint writes the complete current representation as version 2. This uses the same save-before-publication transaction as gameplay: a failed continuation write leaves both the old file and live session unchanged, and retrying the action uses the same pre-action random streams. There is no separate migration write or partially migrated profile.

Historical defaults belong only to the codec's version-1 migration. The current state and statistics decoders require all nonoptional fields, so version-2 corruption cannot fall back to historical defaults. Optional values retain normal Codable omission when absent; authoritative restoration checks when the match requires them. Checkpoints retain rule configuration, stroke maximums, the latest ordinary knocker, Poverty membership and responses, remaining and removed cards, pending challenges, public revelations, tiebreak state, and all counters. Invalid configurations and inconsistent state are rejected rather than silently repaired.

The codec reads the version before interpreting the payload. Unknown versions produce `unsupportedVersion`; malformed data produces `corruptData`; inconsistent decoded contents produce `invalidContents`. Read/write failures also have typed errors. These carry no UI text and can be mapped to Apple's string catalog by presentation code. A missing file means a new local profile.

`GameEngine(restoring:)` validates card conservation and bounded structure, reconstructs the start of the saved round, and checks that accepted actions reproduce the exact snapshot through existing rule validation. Standard historical saves use the existing play/Knock reconstruction. Configured House Rules retain a private current-round journal with its original deal, starting player totals, and actions: public plays alone cannot reconstruct exchanged hands. Tiebreaks retain their own deal and card actions. Neither journal reaches a player view.

Earlier completed rounds must also be supported by prior scoring progress: each costs at least one unit, with each player's strokes capped at the configured maximum for this check. Current-round penalties are excluded. This is a necessary consistency check, not full match replay. Restore validation emits no application events, consumes no saved random stream, and never recounts statistics or draws pending replacement cards.

A failed load leaves the file untouched. The app reports a localized error and offers a new game using `GameSession.empty(store:)`. Creating the empty session alone does not overwrite anything; only a successful new-match save replaces the file. `LocalGameStore.remove()` also remains available for explicit recovery. Compatible migrations belong at the codec's version switch when needed; changes to the persisted schema or restoration semantics require an explicit compatibility decision and a version bump where necessary.

The committed pre-V4 reader accepts only version 1 and rejects version 2 before decoding its payload. This prevents ordinary downgrade loading and continuation from silently discarding House Rules or their lifetime counters, including in a standard-rules match. It cannot prevent an older app's explicit New Game/recovery flow from replacing an unreadable file, deliberate file deletion, or restoration of an older backup. Version-1 files written by earlier V4 development builds remain readable, but acquire this downgrade boundary only after a successful version-2 write.

## Human statistics

All counters are human-scoped and stored locally. The [product specification](../PRODUCT_SPEC.md#v4-statistics) defines the additional House Rules semantics; the Statistics screen displays both the original and House Rules counters.

| Counter | Recorded fact |
| --- | --- |
| Matches played | Match reaches a winner or draw, even if the human was eliminated earlier. |
| Matches won | Human is the match winner; a draw is not a win. |
| Rounds played | A round the human was dealt into reaches a terminal outcome. It still counts after the human Passes or is eliminated during it. Later bot-only rounds do not count. |
| Rounds won | Human is the active round winner. A passed card winning with `noActiveWinner` does not count. |
| Knocks made / held / passed | Successful human Knock / Hold / Pass actions only. |
| Highest stake reached | Maximum authoritative stake observed during accepted transitions while the human participates, including their Pass action. It freezes once the human leaves that round and excludes later bot-only raises. |
| Eight-Card-Rules played | A completed tiebreak in which the human participated. Starting, saving, or restoring an unfinished tiebreak does not count. |
| Eight-Card-Rules won | The human wins that tiebreak's eighth trick, recorded at the same completion point as played. |
| Four Pictures exchanges | The human actually receives four replacement cards after a successful claim. |
| Four Pictures bluffs | A false human claim is unchallenged and completes an exchange; this also increments exchanges. |

Round participation comes from retained hand entries, which remain present even when a dealt player has no cards left, Passes, or is eliminated. Current participation and the human's Pass event define the stake boundary: passing at stake two followed by bot raises to three leaves the human maximum at two.

Counters consume only newly accepted engine events during a checkpoint commit. Restoration loads them directly and produces no historical events, so opening a finished round or terminal match cannot recount it. Failed or illegal actions do not count.

Tiebreaks never count as ordinary rounds. Their completion records one match result and, for a participating human, the applicable tiebreak counters in the same atomic checkpoint. Validation rejects tiebreak totals or wins exceeding their corresponding match counters. An earlier-eliminated human still receives the normal match loss but no tiebreak participation. Completing a restored tiebreak counts once; a failed save rolls back its result and counters together.

Four Pictures statistics inspect only the human's own pre-exchange hand when an actual exchange event is accepted. This private classification does not verify or reveal an unchallenged claim to other players. Exposed false claims, interrupted exchanges, and bot exchanges contribute nothing. Actual human Poverty Hold/Pass choices retain the existing response counters; forced poor participation and the automatic raise create no artificial Hold or Knock.

`resetStatistics()` atomically zeros every counter without changing the match. Only subsequent accepted transitions contribute; if the human is still participating, the next transition observes that round's current stake. Reset after Pass does not recover the earlier stake. Reset after elimination followed by bot-only match completion legitimately yields one match played and zero rounds played. Validation therefore allows matches played to exceed rounds played, and never requires the human's highest stake to cover the current round's stake, even for a just-reset participating human.

## Verification

Non-UI tests cover legal bot actions, deterministic tactics and full matches, hidden-information boundaries, ordered responses, human pauses, exact restored continuation, human-scoped statistics, resets, winner/draw outcomes, corruption, and file operations. Configuration and complete-match tests cover all nine count/difficulty combinations. Tests compare Medium with V1, restore each difficulty during partial tricks and pending responses, and check Skip to Result against ordinary progression. Two-seat scenarios verify that a lone opponent's Pass immediately ends the round, taking precedence over any committed trick winner. Rollback tests exercise deals and their random stream, terminal scoring, a later failure within automatic progression, resets, changing configuration on new-match replacement, and an unwritable existing save. Existing engine playout tests restore every intermediate state across two, three, four, and eight seats. V4 tactics tests cover both elimination thresholds, repeated exchanges, restrained bluffs, stale versus retained revelations, and hidden-card permutations. Complete matches cover representative House Rules combinations at every count and difficulty, comparing restoration after each action. Tiebreak tests cover two through four participants, exact decision-RNG restoration, and a crafted final-card preservation advantage for Hard. Fixed draws and seeds verify the Medium reduction without statistical sampling.

`TuppenTests/Fixtures/version-1-pending-knock.json` is a fixed compatibility fixture without count or difficulty fields: an ordered first deal with Bob's Knock, Charlie's Hold, and Alice's response pending. Maintain it independently of the encoder so schema changes cannot hide behind round-trip tests. There are no automated UI tests.

Run `python3 Tools/check_legacy_save_compatibility.py` on macOS with Xcode and the repository's Git history to verify the downgrade boundary. It compiles the committed pre-V4 reader, checks its rejection of current version-2 checkpoints, and demonstrates the explicit recovery limitation using temporary files. Migration tests also cover missing-field defaults, strict current decoding, and a failed first version-2 write followed by an identical retry.
