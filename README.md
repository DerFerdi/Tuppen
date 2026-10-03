# TUPPEN

An offline-first iPhone implementation of the traditional German card game Tuppen, built with Swift and SwiftUI. No accounts, ads, or analytics.

Play a complete three-player match against two computer opponents, continue a locally saved game, and view local statistics. The functional SwiftUI interface supports German and English, with native cards and explicit round results. Sound, haptics, and final animation polish are still to come.

## Build and test

Open `Tuppen.xcodeproj` and select the shared **Tuppen** scheme. The project uses Swift 6 and targets iPhone on iOS 18 or later. It has no third-party dependencies.

Build the app for the simulator:

```sh
xcodebuild -project Tuppen.xcodeproj -scheme Tuppen \
  -destination 'generic/platform=iOS Simulator' build
```

List installed destinations, then run the Swift Testing unit suite with an available iPhone simulator ID:

```sh
xcodebuild -project Tuppen.xcodeproj -scheme Tuppen -showdestinations
xcodebuild -project Tuppen.xcodeproj -scheme Tuppen \
  -destination 'platform=iOS Simulator,id=SIMULATOR_ID' \
  -only-testing:TuppenTests test
```

There is no UI-test target. UI and visual verification are performed manually.

## Repository guide

- [Product specification](PRODUCT_SPEC.md): product scope and game rules.
- [Contributor instructions](AGENTS.md): architecture, documentation, and testing standards.
- [Game engine](Documentation/GameEngine.md): API, state transitions, information boundaries, and rule assumptions.
- [AI and persistence](Documentation/AIAndPersistence.md): bot decisions, session orchestration, versioned saves, and statistics semantics.
- [App presentation](Documentation/AppPresentation.md): navigation, session integration, localization, preferences, and manual verification.
- `Tuppen/Domain`: Swift value types and the authoritative rules engine, independent of SwiftUI.
- `Tuppen/AI`, `Tuppen/Application`, `Tuppen/Persistence`: restricted bot strategies, game sessions, and local storage.
- `Tuppen/Presentation`: observable application state and focused SwiftUI screens.
- `Tuppen/Resources/Localizable.xcstrings`: English/German string catalog.
- `TuppenTests`: deterministic rule and bot scenarios, information boundaries, full matches, persistence, statistics, and application integration.
