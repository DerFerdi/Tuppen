# TUPPEN

This document is the authoritative product and game specification for TUPPEN.

The completed current development baseline includes V2 opponent-count selection and V3 Easy / Medium / Hard difficulty. Sections describing V1 retain the original release scope. The standard rules below remain the default; only the explicitly enabled options in [V4 House Rules](#v4-house-rules) override them. V4 is current specification work, not implemented or released functionality.

## Product

TUPPEN is a small, polished, offline-first iPhone adaptation of the traditional German card game Tuppen, played particularly in the Rhineland and Lower Rhine region of Germany.

The app should feel closer to a real card table than to a typical mobile game.

Product philosophy:

**Offline first. Online optional.**

There are:

* no accounts
* no ads
* no analytics
* no virtual currencies
* no daily rewards
* no artificial progression systems
* no unnecessary gaming platform around the game

The intended experience is:

**Open the app → get cards → play.**

The project should prioritize a small number of features executed extremely well rather than feature count.

## Platform

V1 targets:

* iPhone only
* Swift
* SwiftUI
* Swift 6
* iOS 18+
* native Apple frameworks wherever practical
* portrait-oriented gameplay initially
* fully offline gameplay against computer opponents

Avoid third-party dependencies unless there is a compelling reason.

## Languages

V1 must support:

* German
* English

The player can choose:

* System
* Deutsch
* English

All user-facing strings must use Apple's localization infrastructure so adding more languages later is straightforward.

Game logic must never depend on localized strings.

In German, Tuppen is the name of the game; Klopfen is the action of raising the stake (English: Knock).

All source code, comments, tests, and repository documentation remain English.

## V1 Scope

V1 includes:

* one human player
* two computer opponents
* one fixed Tuppen ruleset
* German and English UI
* card dealing
* playing cards
* following suit
* four tricks per round
* Knock / Klopfen
* Hold / Halten
* Pass / Passen
* strokes
* player elimination
* match victory
* simple tutorial
* automatic local game continuation
* local statistics
* sound
* haptics
* minimalist premium interface
* accessibility support

V1 does not include:

* configurable player counts
* selectable AI difficulty
* configurable regional rules
* multiplayer
* Game Center
* accounts
* cloud synchronization
* leaderboards
* achievements
* ranked gameplay
* in-app purchases
* ads
* analytics

## Deck

Use a 32-card French-suited deck.

Suits:

* Clubs
* Spades
* Hearts
* Diamonds

Ranks from weakest to strongest:

1. Jack
2. Queen
3. King
4. Ace
5. Seven
6. Eight
7. Nine
8. Ten

Ten is the strongest rank.

Jack is the weakest rank.

There is no trump suit.

Every active player receives exactly four cards.

Unused cards remain hidden and must not influence AI decisions.

## Trick Rules

The first active player to the left of the dealer leads the first trick.

The first card played determines the lead suit. Once established, the original lead suit remains authoritative for the entire trick, even if its player later Passes or is eliminated. Passing never changes follow-suit obligations or the interpretation of cards already played.

Every other active player must follow the lead suit if they hold at least one card of that suit.

If they cannot follow suit, they may play any card.

Only cards matching the lead suit can win the trick.

The highest-ranked card of the lead suit wins.

The winner of a non-final trick leads the next trick if still participating in the round. If that player has Passed, the next still-participating player in table order after them leads instead, skipping passed and eliminated seats and wrapping around the table.

A normal round contains four tricks.

The central Tuppen rule is:

**Only the fourth and final trick determines the result of a normally completed round.**

Winning tricks one, two, or three has no direct scoring value.

A card already committed to the table remains physically and logically part of that trick after its player Passes. It remains eligible to win under the original lead suit and rank ordering. A trick won by such a card is still recorded as belonging to that player; the player does not return to the round.

If a passed player's committed card wins the fourth trick, the round has no active winner. Every player still participating receives the current stake as a losing penalty. The passed player receives no additional penalty beyond the Pass penalty already applied. The trick winner and the round outcome must be represented separately.

## Strokes

Every player starts with zero strokes.

Without knocking, every player who loses the round receives one stroke.

An active winner of the round receives no losing strokes. When the fourth-trick winner has Passed, no remaining participant receives this immunity.

A player is eliminated from the match when their total reaches or exceeds seven strokes.

The match continues with the remaining players.

When the human has been eliminated and only computer players remain, they may choose Skip to Result (German: Zum Ergebnis). This skips presentation only: the remaining match still runs through the authoritative engine with normal saving and statistics, then shows the final result.

The final remaining player wins the match. Determine the match result only after all penalties for the round have been applied. If final-trick scoring with no active winner eliminates every remaining active player simultaneously, the match ends in an explicit draw with no winner.

The engine must therefore support the active player count decreasing during a match.

## Knocking

Knocking is the signature mechanic of the game.

The initial stake of every round is 1.

A legal knock increases the stake by exactly one.

Example:

* initial stake: 1
* first knock: 2
* later valid knock: 3
* later valid knock: 4

### Critical turn rule

Only the player whose turn it currently is may knock.

Knocking can only happen before that player plays their card.

Conceptually:

Turn begins
→ player may knock
→ Hold / Pass responses are resolved
→ if opponents remain, the same player plays a card
→ turn ends

Once the player has played their card, they cannot knock during that turn.

The player who initiated a knock cannot immediately knock again during the same turn.

Another knock can only occur later when an eligible active player reaches their own turn.

This must be enforced by the game engine, not only by the UI.

## Hold

After a knock, the other active players still participating in the round must respond.

Holding means accepting the newly increased stake and remaining in the round.

Example:

Stake before knock: 1
Stake after knock: 2

A player holds.

If that player later loses the round, they receive 2 strokes.

## Pass

Passing means immediately leaving the current round.

The passing player receives the stake that existed before the latest raise.

Example:

Stake before knock: 1
Stake after knock: 2

A player passes.

Penalty: 1 stroke.

If the stake was raised from 2 to 3, passing causes a penalty of 2 strokes.

A player who passes:

* immediately leaves the current round
* receives the appropriate strokes
* takes no more turns during that round
* plays no further cards; already-committed cards remain eligible in their trick
* remains part of the overall match unless the penalty eliminates them

Their remaining cards have no effect on the current round.

The passing penalty is their final penalty for that round; they do not also receive losing strokes when the round ends.

## Resolving a Knock

Normal card play pauses while responses to a knock are unresolved.

Every required opponent must respond with Hold or Pass in deterministic table order:

1. Begin with the next still-participating player after the knocker.
2. Continue around the table, skipping players who have left the round.
3. Only the currently expected responder may submit Hold or Pass.
4. Stop after every required response has been resolved.

Each response becomes public immediately. Later responders intentionally see earlier Hold/Pass decisions before choosing. V1 does not use simultaneous hidden responses. The engine must expose the expected responder and remaining response order so UI and AI do not reconstruct these rules.

No card may be played while required responses remain.

When all responses are resolved:

### At least one opponent remains

Control returns to the player who initiated the knock.

That player remains the current player and must now play a legal card.

They may not knock again during the same turn.

### Every opponent passes

The knocking player immediately wins the round.

Do not play or evaluate any remaining unfinished trick. Immediate victory takes precedence even if a committed card belonging to a player who Passed would otherwise win that trick.

## V4 House Rules

V4 adds optional House Rules to the existing game. This section is the authoritative specification for those options and their interactions. It does not describe functionality already implemented or released.

### Product terminology

Use these terms consistently in product text and localization:

| English | German |
| --- | --- |
| House Rules | Hausregeln |
| Poverty | Armut |
| poor | arm |
| Consecutive Knock Restriction | Klopfsperre |
| Four Pictures | Vier Bilder |
| Eight-Card-Rule | Achter-Brief |

Consecutive Knock Restriction / Klopfsperre is a neutral descriptive term. No traditional regional name is specified for that restriction.

### Match configuration and defaults

Each match has one immutable House Rules configuration, chosen when the match is created and shared by all participants.

| Option | Allowed values | Standard default |
| --- | --- | --- |
| Maximum strokes | 7 or 10 | 7 |
| Poverty | Off or on | Off |
| Consecutive Knock Restriction | Off or on | Off |
| Four Pictures | Off or on | Off |
| Four Pictures bluffing | Off or on; requires Four Pictures | Off |
| Eight-Card-Rule | Off or on | Off |

With maximum strokes set to 7 and every option off, behavior must remain equivalent to the current standard rules. Selecting 10 changes the elimination threshold, not card ranking, scoring amounts, or other disabled mechanics. A participant is eliminated on reaching or exceeding the configured maximum. Every rule that refers to one stroke before elimination uses `maximumStrokes - 1`: six for a maximum of seven, nine for a maximum of ten.

Opponent count and difficulty remain independent match options. Every House Rules configuration must compose with one, two, or three computer opponents and Easy, Medium, or Hard difficulty. There are no per-House-Rule difficulty settings. Bots must obey the active rules through engine-provided legal actions and the existing restricted information boundary.

### Poverty

When Poverty is enabled, determine the poor participants exactly once at the beginning of each normal round, before any card is played or any normal turn action is taken. Every active participant with exactly `maximumStrokes - 1` strokes is poor for that round. Multiple participants may be poor. Later stroke changes never create or remove Poverty during that round; evaluate it again only at the next normal round's start.

If nobody is poor, the round begins normally at stake 1. If at least one participant is poor, it is a Poverty round:

1. Raise the initial stake from 1 to 2 automatically, once regardless of how many participants are poor. This is not an ordinary player-initiated Knock and does not assign a technical knocker.
2. Every poor participant must remain in the round and cannot Pass. They are not asked for a Hold/Pass choice.
3. Ask every non-poor active participant to Hold or Pass in normal deterministic table order: traverse the round's dealer-relative order, beginning to the dealer's left and wrapping around. Skip poor participants, who have no choice to Pass, and seats that are no longer active in the round. Only the expected responder may act; each response is public before the next decision. This uses the engine's existing table-order principles, with no special Poverty ordering.
4. Hold accepts stake 2. Pass immediately leaves the round and charges the previous stake, exactly 1 stroke. It is the participant's only Pass penalty for that round.
5. Resolve these responses before any card is played. If exactly one poor participant remains after all non-poor participants Pass, that poor participant wins the round immediately. If two or more poor participants remain, they play the round against each other. If non-poor participants Hold, they also remain in play.

If all active participants are poor, there are no responses to request; play begins at stake 2. Normal seating and opening-lead rules apply to the remaining participants.

For the entire Poverty round, nobody may Knock or claim Four Pictures. Four Pictures bluffing and exchanges are also unavailable. These restrictions do not end when the initial responses finish. The automatic raise neither counts as an ordinary Knock nor changes the participant remembered by the Consecutive Knock Restriction.

### Consecutive Knock Restriction

When enabled, remember the participant who made the most recent successful ordinary player-initiated Knock in the match. That participant may not Knock again until a different participant makes an ordinary Knock. Before the first ordinary Knock, this restriction excludes nobody.

The remembered participant persists across round boundaries. Winning a round, dealing another round, making a Four Pictures claim, or entering a Poverty round does not reset it. Invalid Knock attempts and automatic Poverty raises do not update it. This restriction is additional to the standard requirement that only the current player may Knock before playing, at most once in that turn.

For example, A Knocks and nobody else Knocks that round. A remains unable to Knock in the next round. Once B makes an ordinary Knock, A becomes eligible under this restriction and B becomes restricted. Other turn and round restrictions still apply.

### Four Pictures eligibility and exchange

A truthful Four Pictures hand has four picture cards. For TUPPEN, the picture-card ranks are Jack, Queen, King, and Ace. Each of the four cards must have one of those ranks; repeated ranks are explicitly valid and the ranks do not need to differ. Suit is irrelevant.

Valid examples include:

* Jack, Jack, Jack, Jack.
* Jack, Jack, Queen, Queen.
* Queen, King, King, Ace.
* Jack, Queen, King, Ace.

Any hand containing a Seven, Eight, Nine, or Ten is not Four Pictures.

There is no separate Four Pictures phase before gameplay. A normal round begins immediately, subject to the Poverty response procedure when applicable. A participant may claim Four Pictures only when all of the following hold:

* Four Pictures is enabled.
* The participant is still participating and it is their normal card turn, with no response or challenge unresolved.
* The round is not a Poverty round and the match is not in the Eight-Card-Rule.
* The participant has not played any card during this round and still holds four cards.
* The participant has not made an ordinary Knock during this turn.
* At least four cards remain in the undealt draw pile.
* If bluffing is disabled, all four cards in the current hand are picture cards.

Other participants may already have played into the first trick before a later seat claims. The claim does not erase those plays or change the established lead suit. Once a participant plays their first card, they cannot claim again during that round.

After an accepted or proven truthful claim, provided challenge resolution has not ended the round, remove the claimant's current four-card hand from the round and draw four replacement cards from the remaining undealt pile. Removed hands do not return to that pile during the round. Replacement cards are private to the claimant. The claimant has still played no card, and the same normal turn continues.

There is no one-claim-per-participant limit. The participant may claim again while all eligibility conditions still hold, including after receiving another qualifying hand. With bluffing enabled, the replacement hand need not be truthful to make another claim. Fewer than four remaining undealt cards prohibit any further claim; do not accept a claim and then discover that replacement cards are unavailable.

An exchange does not consume, grant, or reset Knock eligibility. The legal order on the participant's own turn is:

1. Optionally claim Four Pictures and resolve the exchange or challenge completely. Further eligible claims may repeat this step.
2. Optionally make an ordinary Knock if otherwise legal, including under the Consecutive Knock Restriction, and resolve its responses.
3. Play a legal card if the round continues.

Once the participant Knocks, Four Pictures is unavailable for the rest of that turn, including after their Knock responses finish. They must play a card next if the round continues. Another participant's earlier ordinary Knock does not disable Four Pictures globally: a participant who has not yet played may still claim on their first turn if all eligibility conditions hold. No claim is allowed while any Knock responses are pending.

### Four Pictures bluffing and challenges

Four Pictures bluffing is a separate option that requires Four Pictures to be enabled. Enabling bluffing without Four Pictures is invalid.

With bluffing disabled, there is no challenge flow. The authoritative engine validates the claimant's own hand internally and permits the exchange only if all four cards are picture cards. Other participants are not asked to verify or challenge, and this private validation does not reveal the hand.

With bluffing enabled, the actual ranks do not determine claim eligibility; all timing, participation, and draw-pile requirements still apply. A hand containing any Seven, Eight, Nine, or Ten makes the claim false, but making that claim is legal while bluffing is enabled.

Only with bluffing enabled, offer challenges immediately after the claim and before the claimant receives or sees any replacement card. Eligible challengers are other participants currently active in the round. Anyone who already Passed, is eliminated, or otherwise left the round cannot challenge. Begin with the next active participant after the claimant and proceed in deterministic table order, wrapping around and skipping ineligible seats without asking the claimant.

Only the expected participant may decide whether to challenge. Declining is not a Pass: it causes no stroke or participation change. The first challenge immediately resolves the claim, and no later participant is asked. Apply the following outcomes, with immediate elimination and round resolution taking precedence as described below:

| Resolution | Public information | Stroke effect | Hand and continuation |
| --- | --- | --- | --- |
| Nobody challenges | Accept without verification; the old hand stays hidden, with no new reveal. | None. | Exchange the old hand for four new cards and continue the same turn. |
| A truthful claim is challenged | Reveal the claimant's original four picture cards before replacement; repeated ranks are valid. | Challenger receives exactly 1 stroke. | Claimant completes the exchange and continues the same turn if the round continues. |
| A false claim is challenged | Reveal the claimant's original four cards, including at least one Seven, Eight, Nine, or Ten. | Claimant receives exactly 1 stroke. | No exchange; claimant keeps or receives back that same hand and continues the turn if still active and the round continues. |

The challenge penalty is always 1 stroke, independent of the current stake. A challenged hand becomes public knowledge; keeping that hand after a false claim does not make its revealed contents secret again. An unchallenged discarded hand remains hidden unless an earlier challenge already revealed its cards. Accepting another claim does not erase that public knowledge. All unseen replacement cards remain hidden from other participants and bots.

### Challenge strokes and immediate elimination

Challenge strokes never recalculate Poverty. For example, with maximum strokes 7, a participant who starts at five strokes and receives a challenge stroke reaches six but does not become poor during that round. The same principle applies at eight to nine strokes with maximum strokes 10. A non-Poverty round therefore does not lose access to Four Pictures because of a later challenge stroke.

Elimination is different: reaching the configured maximum through a challenge immediately eliminates that participant from the match and removes them from the current round. They receive no later card turn. An eliminated claimant does not resume their turn; an eliminated challenger cannot take part in later decisions.

Any card that the eliminated participant already committed to the current trick stays physically and logically in that trick and may still win it under the original lead suit. Apply the existing departed-winner fallback for the next lead; a departed winner does not return to play. If they had not played a card, they simply leave the round. A Four Pictures claimant cannot already have played under the eligibility rule, but a later claimant's challenger may have done so.

Resolve the challenge penalty and elimination immediately. If only one active participant remains in the round, that participant immediately wins the round, even if other match participants previously Passed and still survive in the match. Use the existing authoritative round-resolution semantics: do not finish the interrupted trick, continue the claimant's turn, or perform a pending exchange after the round has ended. This immediate victory takes precedence over a departed participant's committed card winning the unfinished trick; the card itself stays in the trick record. If the round continues, that card remains eligible to win when the trick resolves.

The sole surviving match participant still wins the entire match under the existing rule. If an eliminated claimant leaves more than one participant in the round, normal table order advances past that departed seat; it does not return control to the claimant.

### Poverty takes precedence over Four Pictures

The poor-participant set fixed at normal round start determines this precedence for the whole round. If that set is nonempty, nobody may claim, bluff, or exchange Four Pictures. Challenge-caused strokes in a non-Poverty round cannot activate this restriction retroactively.

### Eight-Card-Rule trigger and participants

When enabled, the Eight-Card-Rule replaces the standard Draw in exactly one situation: the final remaining match participants would all be eliminated simultaneously, leaving no winner. Evaluate this after the complete simultaneous scoring batch, rather than after an individual participant's penalty. If any match participant survives, the rule does not trigger.

Only the participants in that final simultaneous elimination enter the tiebreak. Previously eliminated participants do not return, including the owner of a departed winning card if that owner was eliminated earlier. Preserve the eligible participants' relative seating order. Their stroke totals no longer determine the winner once the tiebreak begins. This is a continuation of the same match, not a new match or a normal round.

When the option is off, the existing Draw outcome remains unchanged. When it is on and triggers, do not first finalize a Draw and then reopen that finished match.

### Eight-Card-Rule setup and play

Use the existing 32-card deck and deal exactly eight cards to each eligible participant:

| Tiebreak participants | Cards dealt | Cards not dealt |
| --- | --- | --- |
| 2 | 16 | 16 |
| 3 | 24 | 8 |
| 4 | 32 | 0 |

The supported local match sizes are two to four total participants. Prepare the complete 32-card deck using the normal injected shuffle/deal process. Use the normal deterministic dealer and table-order principles, restricted to the final tied participants: advance from the previous dealer to the next participating seat, deal one card at a time starting to that dealer's left for eight circuits, and let the first participating seat to the dealer's left lead. Skip every seat outside the tiebreak. Preserve relative seating order; there is no special tiebreak seating or leader-selection rule.

Play exactly eight tricks. Normal lead-suit and mandatory-follow-suit rules apply, with the existing rank order and no trump suit. A trick winner leads the next trick when applicable; the existing fallback for a departed winner remains the rule where relevant. Winning tricks one through seven has no direct scoring effect. Only the eighth trick decides the match, and its winner immediately wins the entire match.

There is no normal round scoring after this tiebreak. Do not use retained stroke totals to select or disqualify its winner.

During the Eight-Card-Rule, all of the following are unavailable:

* Ordinary Knock and its Hold/Pass responses.
* Poverty and its automatic raise.
* Four Pictures, including bluffing and challenges.
* Four-card exchanges and eight-card exchanges.
* Any analogous Eight Pictures / Acht Bilder mechanic.

The Eight-Card-Rule is a direct match tiebreak. It does not introduce another exchange rule.

### Compatibility and hidden information

Outside the explicit enabled overrides, retain the standard 32-card deck, rank order, follow-suit obligation, fixed lead suit, normal four-card deals and fourth-trick scoring, Pass penalty, committed-card survival, departed-winner fallback, deterministic Knock responses, and immediate victory when all opponents Pass.

Bots remain limited to their own hand and public information. Public challenge revelations are legitimate knowledge; hidden opponent hands, unverified discarded hands, undealt card identities, and future randomness remain inaccessible. Legal actions and pending decisions must come from the authoritative engine, including disabled options, expected responders, forced participation, and repeated exchange eligibility. No difficulty receives privileged information.

### Future V4 statistics

Keep all statistics local, human-scoped, and driven by accepted authoritative transitions, with no recount on restore. The following additional counters are V4 requirements, not implemented statistics:

| Counter | When to increment |
| --- | --- |
| Eight-Card-Rules played | Once when a tiebreak reaches its terminal outcome, if the human was one of its participating final tied players. |
| Eight-Card-Rules won | Once when the human wins the eighth trick and therefore that tiebreak and match. |
| Four Pictures exchanges | Once per four-card exchange actually completed by the human, whether truthful with or without a challenge, or a successful unchallenged false claim. |
| Four Pictures bluffs | Once per false human Four Pictures claim that nobody challenges and that actually completes an exchange. |

An Eight-Card-Rule is a match tiebreak, not an additional ordinary scored round. It increments neither `roundsPlayed` nor `roundsWon`. A tiebreak that occurs after the human was eliminated earlier contributes nothing to the human's Eight-Card-Rules played or won counters. A human included in the final simultaneous elimination is a tiebreak participant and is eligible for those counters.

The tiebreak produces only one final match result. A would-be Draw that enters it is not a completed match. Preserve the completed normal round's statistics without erasing or recounting them. At the tiebreak's terminal outcome, record match played and any human match win using the existing match-counter semantics, including a match loss after earlier human elimination.

A successful unchallenged human bluff increments both Four Pictures exchanges and Four Pictures bluffs. A truthful completed exchange increments only exchanges. An exposed false claim increments neither counter, because no exchange occurs. Nor do incomplete exchanges, truthful claims without an exchange, or any other participant's actions increment these counters. Repeated completed human exchanges each count once. In particular, if a challenge penalty ends the round before replacement cards are drawn, no exchange is recorded.

Classifying a completed human exchange for the bluff counter may inspect that human's original hand privately. This statistical bookkeeping does not challenge, reject, or reveal an unchallenged claim, and it must not expose another participant's hidden discarded hand. Acceptance of an unchallenged claim remains independent of whether it was truthful.

A Poverty raise or Four Pictures declaration/challenge is not an ordinary human Knock. Forced participation by a poor participant is not a human Hold action. Actual human Hold/Pass choices during Poverty retain the existing action-count meanings, and highest stake retains its human-participation boundary. Challenge penalties are strokes, not additional Knock/Hold/Pass actions or separate rounds.

The new counters follow the existing atomic-save and reset semantics: save them with the accepted transition, do not count failed saves or restored historical events, and let a reset affect counters without changing the match. Historical profiles without these counters start them at zero; do not reconstruct them from old play.

### Persistence and future New Game direction

The immutable House Rules configuration must eventually be saved with the match. Continue must restore those exact settings. Changing the choices for a future New Game must not mutate an existing checkpoint. Historical saves without a V4 configuration must load with maximum strokes 7 and Poverty, Consecutive Knock Restriction, Four Pictures, Four Pictures bluffing, and Eight-Card-Rule all off. Existing opponent-count and difficulty compatibility remains intact.

Restoration must also preserve the logical progress needed by the active rules: the round-start poor-participant set, last ordinary knocker across rounds, pending Poverty or challenge decisions, original hand awaiting challenge resolution, remaining draw pile and removed hands, and any tiebreak participation and trick progress. Pending claims cannot draw or reveal replacement cards merely because a match was restored. Existing transactional saving, seeded continuation, and statistics double-count prevention still apply. The eventual save-format decision must account for the new states; this specification does not implement a schema or migration.

The future New Game configuration contains a section named House Rules in English and Hausregeln in German, alongside the independent opponent-count and difficulty choices. It offers maximum strokes 7 or 10 and the five rule toggles above. Four Pictures bluffing is configurable only when Four Pictures is enabled; disabling Four Pictures must not leave an enabled dependent option. This is product direction only, without a prescribed control layout or implemented UI.

## Game Engine

The game engine is the authoritative source of truth.

It must be independent from SwiftUI.

The UI must not independently calculate:

* legal cards
* legal knocks
* trick winners
* round winners
* strokes
* eliminations
* match victory

Prefer an action/state/event architecture:

Current state + requested action → engine validation → new authoritative state + resulting events

Potential actions include:

* playCard
* knock
* respondToKnock
* startNextRound

Potential events include:

* roundStarted
* cardPlayed
* playerKnocked
* playerHeld
* playerPassed
* trickWon
* roundEnded (with an active winner or explicitly no active winner)
* strokesAdded
* playerEliminated
* matchWon
* matchDrawn

The exact API may differ if a cleaner Swift design is found. Creating a match and starting subsequent rounds must expose the same round-start lifecycle: one `roundStarted` event per new round, after dealing. Consumers must not need a special case for round 1.

## Legal Actions

The engine should provide a clear way to determine legal actions for a player.

Before the current player's card has been played, legal actions may include:

* Knock
* Play legal card A
* Play legal card B
* etc.

After that player has knocked and all responses have resolved, legal actions may include legal card plays but must not include another immediate Knock.

While knock responses are pending, normal card-playing actions are unavailable. Only the expected responder has legal Hold/Pass actions; later responders must wait.

## Hidden Information

Computer opponents must not cheat.

A bot may know:

* its own hand
* cards already played publicly
* previous public tricks
* current trick
* current stake
* stroke counts
* player statuses
* whose turn it is
* public knock history, including earlier responses and the expected responder

A bot must not know:

* the human player's hidden hand
* another bot's hidden hand
* undealt cards

Provide a restricted player-facing game representation if needed so AI code cannot accidentally access hidden information.

## Randomness

Randomness must be injectable.

Do not scatter direct random calls throughout the game engine.

Deck shuffling must support deterministic testing using a predefined deck or seeded randomness.

## V1 AI

V1 contains one AI strategy.

There is no difficulty selector yet.

The bot should:

* always obey the rules
* never inspect hidden information
* play sensible legal cards
* understand that only the final trick determines the round winner
* make basic assessments of hand strength
* sometimes knock
* decide whether to Hold or Pass
* remain intentionally imperfect

Do not build an optimal Tuppen solver in V1.

Architecture is more important than perfect play.

## Persistence

An active match should be saved locally automatically.

If the app is terminated and reopened, the player should be able to continue the match exactly where it stopped.

Do not use:

* iCloud
* CloudKit
* remote databases
* accounts

Persist authoritative game state only.

Do not persist transient animation state.

Version the persisted format so future versions can migrate or reject incompatible saves safely.

## Statistics

Statistics remain entirely local.

Suggested V1 statistics:

* matches played
* matches won
* rounds played
* rounds won
* knocks made
* knocks held
* knocks passed
* highest stake reached

These counters describe the human player:

* Count a match once at its terminal result, including a loss after earlier human elimination or a draw. Only a human match victory counts as a win.
* Count a round at its terminal outcome if the human was dealt into it, even if they later Pass or are eliminated during that round. Do not count subsequent bot-only rounds. A round win requires an active human winner; a passed winning card with no active round winner is not a win.
* Count only successful human Knock, Hold, and Pass actions.
* Track the highest stake while the human participates, including the stake at which they Pass. Ignore subsequent raises after they leave that round.
* Reset all statistics to zero without changing the match. Only later accepted game transitions contribute. The next transition while the human participates observes the current stake. After a reset following elimination, match completion can produce one match played with zero rounds played.

Statistics are informational only.

The [future V4 statistics](#future-v4-statistics) add human-only Four Pictures and Eight-Card-Rule counters. They preserve these existing meanings and are not part of the implemented V2 + V3 baseline.

Do not introduce XP, streak rewards, currencies, badges, unlocks, or artificial progression.

## Home Screen

Keep the home screen extremely simple.

Conceptually:

TUPPEN

Continue
New Game

How to Play
Statistics
Settings

Only show Continue when an active saved match exists.

Starting a game should require as little navigation as possible.

## Settings

V1 settings:

* Language
* Sound
* Haptics
* Reset Statistics

Language options:

* System
* Deutsch
* English

Avoid settings without a clear purpose.

## Signature Knock Interaction

The preferred human knock interaction is:

**Double tap the table.**

Only accept this gesture when knocking is currently legal.

A successful knock should feel physical:

1. recognize the double tap
2. trigger two short haptic impacts
3. play a subtle wooden knocking sound
4. give the table a restrained visual response
5. briefly display `TOK TOK`
6. pause normal card flow
7. show opponent responses
8. return control to the knocking player if opponents remain

German responses may display:

* HÄLT
* PASST

English responses may display:

* HOLDS
* PASSES

Provide an accessible explicit Knock action for users who cannot reliably perform the gesture.

## Visual Direction

The app should feel minimalist, quiet, tactile, and premium.

Avoid typical casino-game aesthetics.

Avoid:

* fake gold
* coins
* gems
* glowing buttons
* slot-machine effects
* excessive gradients
* constant particles
* giant HUD elements
* engagement mechanics

Prefer:

* large cards
* generous spacing
* restrained typography
* subtle depth
* short animations
* natural card movement
* table-like spatial composition
* minimal permanent UI

The table itself should effectively be the primary interface.

## Cards

Prefer rendering cards using native SwiftUI rather than relying on copyrighted artwork.

Cards must clearly communicate:

* rank
* suit
* red/black distinction

Cards must also have appropriate accessibility descriptions.

## Sound and Haptics

Use sound and haptics sparingly.

Useful moments include:

* dealing
* playing a card
* knocking
* receiving another player's knock
* collecting a trick
* receiving strokes
* elimination
* match victory

Sound and haptics must each be independently configurable.

## Tutorial

The tutorial must exist in both German and English.

It should explain:

1. Every player receives four cards.
2. Follow suit whenever possible.
3. Rank order is J < Q < K < A < 7 < 8 < 9 < 10.
4. Only the final trick determines the result of a normally completed round.
5. Losing normally costs one stroke.
6. The current player can knock before playing their card.
7. Knocking increases the stake.
8. Hold accepts the higher stake.
9. Pass leaves the round at the previous stake.
10. Seven strokes eliminate a player.
11. The final remaining player wins the match.

The optional How to Play guide on Home teaches these essentials in a short visual sequence. Rare cases involving passed cards, no active winner, and draws belong in the rules reference rather than the beginner tutorial.

## Accessibility

Support:

* VoiceOver card descriptions
* accessible card actions
* accessible Knock action
* sufficient contrast
* Reduce Motion
* Dynamic Type where practical
* communication that does not depend only on color

## Automated Testing

Automated tests should heavily cover the domain and engine.

Do not create or run automated UI tests, XCUITest suites, UI automation, screenshot tests, or snapshot tests solely for UI validation. The project owner performs UI and visual testing manually.

At minimum test:

### Deck

* exactly 32 cards
* all cards unique
* eight cards per suit
* correct rank ordering

### Legal Card Play

* leader may play any card
* following suit is mandatory when possible
* any card may be played when the lead suit is unavailable
* illegal plays are rejected

### Tricks

* only lead suit can win
* rank order is correct
* original lead suit remains fixed after Pass
* committed cards remain eligible after their owners Pass
* a participating trick winner leads the next trick
* a departed trick winner yields the next lead to the next participating seat, including consecutive inactive seats and wraparound
* normal round contains four tricks
* a participating fourth-trick winner wins the round
* a passed fourth-trick winner produces an explicit round outcome with no active winner

### Knocking

* initial stake is one
* only current player may knock
* knock is legal only before playing that player's card
* knock raises stake by exactly one
* same player cannot immediately knock again
* card play pauses while responses are pending
* Hold accepts new stake
* Pass uses previous stake
* passed player leaves the round
* deterministic response order begins after the knocker and wraps around
* inactive seats are skipped
* wrong-player and duplicate responses are rejected
* later responders see earlier public responses
* all opponents passing immediately ends the round
* after responses, control returns to the knocking player

### Scoring

* normal loss adds one stroke
* raised stakes apply correctly
* round winner receives no losing strokes
* passing uses the correct previous stake and is never charged twice
* a round with no active winner charges every remaining participant
* seven strokes eliminates a player
* eliminated players are no longer dealt cards
* match ends with one remaining player
* simultaneous elimination of all remaining players produces a draw
* dealer rotation skips consecutive eliminated seats and wraps around

### Lifecycle and Information Boundaries

* initial and subsequent rounds expose the same round-start event contract
* restricted player views remain free of hidden opponent hands and undealt cards after completed tricks, Pass, elimination, and subsequent turns

### AI

* bot never chooses illegal actions
* bot only acts when allowed
* bot cannot inspect hidden information
* deterministic scenarios can be reproduced

### Persistence

* game state serializes and restores correctly
* interrupted match restores correctly
* transient presentation state is not persisted

## Roadmap

### V1 — Core Game

One human versus two computer opponents.

Focus on making Tuppen feel excellent.

### V2 + V3 — Player Count and AI Difficulty

The completed current development baseline supports selectable numbers of computer opponents:

* 1 opponent
* 2 opponents
* 3 opponents

Do not architect the engine around exactly three players.

Choose one difficulty for all computer opponents in the match:

* Easy
* Medium
* Hard

Difficulty belongs in interchangeable AI strategies rather than the core engine. Defaults are two opponents and Medium, which preserves the V1 strategy. Save the selected count and difficulty with the match; historical saves restore as two opponents on Medium. New Game selects both in one compact sheet, while Continue uses the saved configuration.

### V4 — House Rules

Current work defines the authoritative [House Rules specification](#v4-house-rules): maximum strokes 7 or 10, Poverty, Consecutive Knock Restriction, Four Pictures with optional bluffing, and Eight-Card-Rule. The standard configuration remains the default. These options are specified for future implementation; they are not yet implemented or released.

### V5 — Friends

Add optional private multiplayer using Apple Game Center / GameKit.

No proprietary account system.

No permanent custom backend.

The host device acts as the authoritative game server.

Clients send actions.

The host validates them, updates the same game engine used offline, and distributes the authoritative result.

Host migration is not required for the first multiplayer release.

## Development Phases

The implementation should proceed in these large phases:

### Phase 1 — Foundation and Complete Game Engine

Build the complete non-UI domain and rules engine with strong unit tests.

### Phase 2 — AI and Persistence

Add the V1 bot, hidden-information-safe AI interface, saving, restoration, and statistics.

### Phase 3 — Complete Functional App UI

Connect SwiftUI to the engine and make an entire match manually playable in German and English.

### Phase 4 — Tactile Product Polish

Focus on knocking, animation, sound, haptics, card movement, typography, and overall feel.

### Phase 5 — Tutorial, Accessibility, and Localization Review

Complete onboarding, VoiceOver, Reduce Motion, language coverage, and final usability work.

### Phase 6 — Open-Source and V1 Release Cleanup

Clean the repository, documentation, comments, assets, licenses, README, and release readiness.

## Product Principle

When forced to choose between more features and a better-feeling implementation of Tuppen, choose the better-feeling implementation.

TUPPEN should be a small app that feels finished rather than a large app that feels unfinished.
