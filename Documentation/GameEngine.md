# Game engine

The engine supports the standard rules and optional V4 House Rules. The [product specification](../PRODUCT_SPEC.md#v4-house-rules) defines their precise behavior. The unreleased app interface exposes configuration and decisions through the existing [presentation boundary](AppPresentation.md#house-rules).

`GameEngine` owns a read-only `MatchState` snapshot and is the only component that applies rules. It has no SwiftUI, Foundation, storage, or networking dependencies. The engine and its state are `Sendable` value types, with no implicit main-actor isolation. A caller owns and serializes mutations to its engine instance.

## Starting and advancing a match

```swift
var random = SystemRandomNumberGenerator()
let players = (0..<3).map { PlayerID(rawValue: $0) }
let start = try GameEngine.start(
    players: players,
    deck: Deck.shuffled(using: &random)
)
var engine = start.engine
let initialEvents = start.events // Includes roundStarted for round 1.

let player = players[1] // The seat to the left of the initial dealer.
let view = try engine.view(for: player)
if let action = view.legalActions.first {
    let events = try engine.apply(action, by: player)
    // Present the new state and its public events.
}
```

`GameAction` carries a card play, a Knock, a Knock or Poverty response, a Four Pictures claim, or a challenge decision. `apply(_:by:)` checks membership in `legalActions(for:)` before making any changes. Rejected actions throw `GameError` and leave the authoritative state unchanged. Events describe public facts in resolution order; card identities appear only after play or an actual challenge reveal.

`GameEngine.start` returns a named `(engine, events)` tuple; new-match initialization is private so creation cannot silently omit its lifecycle result. Deliver the returned events to the same consumer used for action and round-advance results. Both creation and `startNextRound` return exactly one `roundStarted` event after dealing. The first card action does not repeat it. `GameEngine(restoring:)` validates a saved snapshot separately and produces no new lifecycle events; see [AI and persistence](AIAndPersistence.md) for restore and statistics semantics.

Round advancement is a table-level operation, separate from player actions:

```swift
if engine.state.phase == .playing,
   case .finished = engine.state.round.phase {
    try engine.startNextRound(deck: Deck.shuffled(using: &random))
}
```

The engine validates every supplied deck as the complete set of 32 unique cards. `Deck(cards:)` accepts a known deal order for exact scenarios. `Deck.shuffled(using:)` consumes only a caller-supplied generator. For reproducibility across toolchain versions, retain an explicit deck order rather than relying on the standard library's shuffle implementation remaining unchanged.

## State and rule ownership

`MatchState` holds seats, strokes, match outcome, the current `RoundState`, immutable `HouseRules`, the last ordinary knocker, and an optional separate `EightCardState`. Eliminated seats retain their identities and positions. `RoundState` contains hands, undealt cards, remaining participants, stake, public knock history, the current trick, and completed tricks. At round end, participation records which players stayed to the end, even if final scoring eliminated them. The last played trick remains available on the table as well as in completed history.

`TrickState` stores the original lead suit when its first card is appended. Its plays are append-only; participation changes never alter the lead or remove a committed card. `Rank` explicitly orders J < Q < K < A < 7 < 8 < 9 < 10. Every committed lead-suit card remains eligible to win, even after its owner Passes or is eliminated.

A departed winner of trick 1, 2, or 3 retains the recorded trick win but gets no further turn. The next participating seat after that winner leads, skipping passed and eliminated players and wrapping around. Earlier tricks have no scoring value.

For trick four, `RoundOutcome.won(winner:reason:)` identifies a participating winner; `RoundOutcome.noActiveWinner(trickWinner:)` records that the winning card belonged to a departed player. Its `winner` is `nil`. Both produce `roundEnded`, while `trickWon` still identifies the committed card's owner. If all opponents pass after a knock, immediate `.won(..., reason: .opponentsPassed)` takes precedence and the unfinished trick is not resolved.

The round phase expresses the knock state machine:

| Phase | Legal actions | Transition |
| --- | --- | --- |
| `playing(.mayKnock(player))` | Engine-advertised cards, Knock, and eligible Four Pictures claims | Card advances play; Knock opens responses; a claim resolves privately or opens challenges. |
| `awaitingResponses(pending)` | Hold or Pass from `expectedResponder` only | Resume the knocker's card turn after all responses, or immediately finish if everyone passes. |
| `awaitingPovertyResponses(pending)` | Poverty Hold or Pass from `expectedResponder` only | Resume the normal opening lead among remaining participants, or finish with a sole poor participant. |
| `awaitingFourPicturesChallenges(pending)` | Challenge or decline from `expectedResponder` only | Resolve the first challenge immediately; all declines accept the exchange without revelation. |
| `playing(.mustPlay(player))` | Legal card plays only | Playing consumes the interrupted turn. |
| `finished(outcome)` | No player actions | Start the next round if the match continues. |

A winner beginning the next trick has a new turn; the standard rules allow another Knock. Enabled House Rules can further restrict it. During an unresolved Knock, `currentPlayer` still identifies the knocker, but only `PendingKnock.expectedResponder` can act. Its `responders` array is the outstanding queue in table order after the knocker, skipping nonparticipants. Both are available through `PlayerView.roundPhase`. Each response is published immediately in events and knock history, then the next responder becomes eligible. Later responders intentionally see earlier choices. `GameEngine.expectedActor` covers every response window and tiebreak turn; callers must still use legal actions rather than infer permission from a current-player identity.

Passing immediately removes the player from the round and charges the previous stake once. Their unplayed cards are irrelevant; committed cards stay in the trick. Final scoring charges remaining participants except an active round winner. With `.noActiveWinner`, every remaining participant receives the stake; passed players never receive a second penalty.

Holding changes no strokes immediately; it accepts the stake for a later loss. Reaching or exceeding `houseRules.maximumStrokes` (7 or 10) eliminates a player, retaining the complete penalty. Resolve the match after the entire scoring batch: one surviving match player produces `.finished(winner:)` and `matchWon`; zero produces `.draw` and `matchDrawn` unless the Eight-Card-Rule is enabled. A surviving player who passed can still be the sole match survivor. Two or more survivors continue to another round, including after a round with no active winner.

## House Rules state

`HouseRules.standard` preserves seven-stroke elimination with every optional rule off. `MaximumStrokes` admits only seven and ten; the throwing configuration initializer rejects bluffing without Four Pictures. Pass a configuration to `GameEngine.start(..., houseRules:)`; later actions cannot change it.

Poverty fixes `poorParticipants` while dealing a normal round. Its separate response queue contains only non-poor participants in dealer-relative order. It has no synthetic knocker, and the retained poor set disables Knock and Four Pictures for the whole round. `lastOrdinaryKnocker` belongs to the match, so the Consecutive Knock Restriction survives dealing another round.

Four Pictures checks the claimant's current four-card hand, with repeated picture ranks allowed. Exchanges consume the next four undealt cards and retain removed hands separately for card conservation. The `.mayKnock` turn remains in place, allowing repeated eligible exchanges; an ordinary Knock changes it to `.mustPlay` and ends claim eligibility for that turn.

With bluffing enabled, `PendingFourPictures` holds only a claimant and ordered responder queue. The original hand stays in authoritative storage until resolution. A challenge produces `RevealedHand`, applies its one-stroke penalty, and resolves elimination or a sole-participant round win before any replacement deal. Public reveals remain known even when a false claimant retains the hand or later exchanges it. Unchallenged hands remain private.

The Eight-Card-Rule first enters `.awaitingEightCardDeal(participants:)` instead of publishing a Draw. The session supplies a fresh shuffled deck to `startEightCardRule(deck:)`, making the deck consumption a separate saved transaction. `EightCardState` retains eligible seats, dealer, hands, eight tricks, and current player independently of the completed normal round. Retained strokes do not determine participation or the winner. Its eighth trick emits `eightCardRuleEnded` and `matchWon`, never `roundEnded` or normal losing penalties.

For presentation and strategy inputs, `PlayerView` projects tiebreak cards and turns through the existing hand/trick fields and identifies them with `isEightCardRule`. Its `MatchPhase` stays distinct, so consumers can distinguish a tiebreak from another scored round.

## Rule assumptions

The product specification leaves the following table procedures unspecified. The engine makes these choices consistently, with regression tests:

- The supplied player order proceeds to the left. The first seat is the initial dealer unless a dealer is supplied explicitly.
- Deal one card at a time, starting to the dealer's left, for four circuits. Advance the dealer to the next surviving seat after every round, including rounds ended by passing. Eliminated seats are skipped for dealing, leading, and play.
- There is no additional stake cap. Each player can raise at most once per card turn, and every player has at most four card turns per round.
- The domain accepts two through eight seats for normal four-card games. With the Eight-Card-Rule enabled, it accepts at most five initial seats so a final tied group fits the 32-card deck. Local sessions remain constrained to two, three, or four total players through `BotCount`; New Game offers one through three computer opponents with two preselected. See [AI and persistence](AIAndPersistence.md#match-configuration).

A four-participant tiebreak is tested through a five-seat domain match. The departed winning-card owner is excluded from the final elimination batch, so supported local matches can actually reach tiebreaks of at most three participants. The tiebreak itself supports and validates two through four participants without changing the local player-count choices.

## Hidden information

`MatchState` is privileged and must not be passed to a bot strategy. `PlayerView` is a separate value containing only the requesting player's hand, public seat information, current and completed tricks, Knock history, House Rules, actual challenge revelations, and engine-computed legal actions. It has no engine reference, opponent-hand dictionary, undealt-card storage, removed hidden hands, or private replay journal. A revealed hand is public gameplay history, not access to that seat's future replacement cards.

The view separates historical revelations from `knownHands` (revealed cards still retained) and `discardedPublicCards` (revealed cards removed by an exchange). These projections use only previously revealed identities and their public disposition; they never publish unchallenged old hands. See [AI and persistence](AIAndPersistence.md#house-rules-tactics) for how strategies use this knowledge.

Tests swap every pair of hidden positions for each player and require the resulting views to remain equal. Further scenarios replay the same public history with different secrets through completed tricks, sequential responses, Pass, elimination, and subsequent active turns. Views and public events must remain equal while opponent hands and undealt cards differ. `BotStrategy` accepts this restricted view and a separate decision generator.

## Localization

The app uses Apple's `Localizable.xcstrings` catalog with English as the source language and German translations. Presentation resolves strings using the selected System/Deutsch/English preference; see [App presentation](AppPresentation.md). Domain identifiers and rules remain independent of translated text.

## Verification

The Swift Testing target covers deck validation, exact dealing, every rank pairing, following suit, rejected-action atomicity, four-trick scoring, knock interruption and resumption, fixed leads after Pass, committed cards winning after their owners leave, next-leader fallback, final-trick outcomes with no active winner, draws, response ordering, initial/subsequent round events, elimination, dealer rotation, reduced tables, and terminal matches. Seeded full-match scenarios exercise two, three, four, and eight seats, comparing every event and state against replay and checking card conservation and progress throughout.

Build and run the unit target using the commands in the repository README. Manually inspect gameplay in English and German using the [app checklist](AppPresentation.md#manual-verification). No UI automation, screenshots, or snapshot tests are part of this workflow.
