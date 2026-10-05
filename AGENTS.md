# TUPPEN Project Instructions

## Project

TUPPEN is an open-source, offline-first iPhone implementation of the traditional German card game Tuppen.

The app is built with Swift, SwiftUI, and native Apple frameworks.

The repository should look and feel like a thoughtfully maintained open-source Swift project.

## Code Quality and Comments

All source-code identifiers must be in English.

All source-code comments must be written in English.

Comments are not optional where they improve understanding.

Write useful, human-quality comments throughout the codebase where appropriate, especially for:

* non-obvious game rules
* unusual Tuppen mechanics
* state-machine transitions
* important invariants
* architectural decisions
* edge cases
* intentionally unusual implementation choices
* public APIs where the purpose is not immediately obvious
* logic where future contributors would otherwise need to reverse-engineer intent

Prefer clear naming and clean code first, but do not use clean naming as an excuse to avoid documentation entirely.

Do not comment every line.

Avoid comments that merely repeat the code.

Bad:

```swift
// Increase the stake by one.
stake += 1
```

Good:

```swift
// A player who passes accepts the stake that existed before the latest raise.
let penalty = previousStake
```

The finished code should read like code written and reviewed by experienced human Swift developers.

Avoid:

* excessive section comments
* obvious comments
* generic explanations that do not clarify the software
* verbose comments that restate implementation details
* comments describing development tools, task instructions, or the authorship process

Comments should describe the software and its intent, rather than how it was produced.

Repository documentation should follow the same standard: concise, intentional, technically useful, and suitable for a public open-source project.

## Language

* All source-code identifiers must be in English.
* All source-code comments must be in English.
* All repository documentation must be in English.
* All test names must be in English.
* The app UI itself must support German and English.
* Never make game logic depend on localized strings.
* All user-facing strings must use Apple's localization infrastructure so additional languages can be added later.

## Architecture

* Keep the authoritative game engine independent from SwiftUI.
* Game rules, legal actions, scoring, trick resolution, knocking, passing, holding, and elimination belong in the domain/game-engine layer.
* SwiftUI should render authoritative state rather than duplicate game-rule logic.
* Prefer simple native Swift architecture over unnecessary abstraction.
* Avoid third-party dependencies unless clearly justified.
* Prefer understandable code over clever code.
* Keep types focused and responsibilities clear.
* Avoid speculative abstractions for features that do not exist yet.

## Testing

Automated tests should focus on:

* game rules
* state transitions
* scoring
* legal actions
* knocking
* AI legality
* hidden-information boundaries
* persistence
* deterministic game scenarios

Do not create or run automated UI tests.

Specifically:

* Do not create XCUITest suites.
* Do not run UI automation.
* Do not create screenshot tests.
* Do not create snapshot tests solely for UI validation.

The project owner performs UI and visual testing manually.

Contributors should build the app and run non-UI unit tests.

Tests should also be written as maintainable open-source code:

* descriptive test names
* clear setup
* minimal duplication
* comments where a test represents a subtle game rule or regression

## Knocking Rule

Only the player whose turn it currently is may knock.

Knocking happens before that player plays their card.

If the player knocks:

1. Increase the stake.
2. Resolve Hold/Pass responses from the other active players.
3. If at least one opponent remains, return control to the knocking player.
4. The knocking player must then play a legal card.
5. The same player cannot knock again during that turn.

If every opponent passes, the knocking player wins the round immediately.

This must be enforced by the game engine.

When this rule results in non-obvious state transitions, document those transitions with concise English comments so future contributors can understand why the state machine behaves that way.

## Product Principles

Offline first. Online optional.

No accounts.
No ads.
No analytics.
No virtual currencies.
No daily rewards.
No artificial engagement systems.

Prioritize a small, polished implementation over feature count.

Use native Apple frameworks where practical.

## Open-Source Standard

Treat every committed file as if an external Swift developer may read, review, modify, or contribute to it later.

The codebase should therefore be:

* readable
* consistently named
* sensibly documented
* unsurprising
* easy to navigate
* free of unnecessary boilerplate
* free of unnecessary abstraction
* focused on software behavior rather than development-process details

Where a short documentation comment or explanatory comment would save a future contributor time, add it.

Where the code is already obvious, leave it clean.

## Workflow

Before substantial changes:

1. Inspect the existing repository.
2. Preserve good existing architecture where appropriate.
3. Plan larger changes before editing.
4. Keep the project buildable.

After implementation:

1. Build the app.
2. Run relevant non-UI tests.
3. Fix failures.
4. Review the diff for unnecessary complexity.
5. Review comments and documentation for clarity and usefulness.
6. Add missing explanatory comments where future contributors would benefit.
7. Remove obvious or redundant comments.
8. Update relevant documentation.
9. Report what changed and what should be manually verified.

Never run UI tests.
