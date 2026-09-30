# TUPPEN

This document is the authoritative product and game specification for TUPPEN.

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
* Tuppen / knocking
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

Statistics are informational only.

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
12. Passing leaves committed cards in play without changing the lead suit. If a passed player wins an early trick, the next remaining player leads.
13. If a passed player wins the final trick, everyone still in the round receives the stake. If nobody survives elimination, the match is a draw.

Prefer concise visual explanations over large text walls.

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

### V2 — Player Count

Support selectable numbers of computer opponents.

Initial targets:

* 1 opponent
* 2 opponents
* 3 opponents

Do not architect the engine around exactly three players.

### V3 — AI Difficulty

Add:

* Easy
* Medium
* Hard

Difficulty belongs in interchangeable AI strategies rather than the core engine.

### V4 — Regional Rules

Add optional regional and house rules under the concept:

**"So spielen wir."**

Potential options include:

* Vier Bilder
* different stroke limits
* alternate knocking rules
* other regional table rules

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
