# TUPPEN

TUPPEN is an open-source iOS adaptation of the traditional German card game Tuppen, played particularly in the Rhineland and Lower Rhine region of Germany.

The app focuses on preserving the character of the game in a simple, offline implementation for iPhone.

## About Tuppen

Tuppen is a traditional trick-taking card game played with a 32-card deck. Its distinctive rules include a round decided by the fourth trick and the option to increase the stakes by knocking. After a knock, the other players must decide whether to hold or pass.

Like many traditional card games, Tuppen has regional and table-specific variations. This project's first version implements one fixed ruleset, described in the [product specification](PRODUCT_SPEC.md).

## Features

- Fully offline play for one human player against two computer opponents.
- German and English interface, with an optional How to Play guide.
- Automatic local saving and match continuation.
- Local statistics.
- Independently configurable sound and haptics.
- VoiceOver controls and descriptions, Reduce Motion, and support for larger text where practical.
- No accounts, advertising, analytics, or remote backend.

## How Tuppen Works

Each active player receives four cards. Players take turns playing one card into a trick and must follow the led suit whenever possible. If they cannot follow suit, they may play any card. There is no trump suit; the highest card of the led suit wins the trick and normally leads the next one.

Ranks run from weakest to strongest:

**Jack < Queen < King < Ace < Seven < Eight < Nine < Ten**

A normal round has four tricks. Only the fourth determines the round winner; earlier tricks determine who leads next. Losing a round normally costs one stroke (*Strich* in German). A player is eliminated at seven strokes, and the last remaining player wins the match.

The stake starts at one. On their turn, before playing a card, a player may **Knock / Klopfen** to raise it by one. The other players respond in table order:

- **Hold / Halten:** stay in the round and accept the higher stake for a loss.
- **Pass / Passen:** leave the round and receive the stake from before the raise as strokes.

If every opponent passes, the knocking player wins the round immediately. Otherwise, play resumes with that player, who must now play a card.

## Screenshots

Screenshots will be added for the first public release.

## Languages

The interface supports German and English. Settings can follow the system language or select either language explicitly.

User-facing text is maintained in Apple's [string catalog](Tuppen/Resources/Localizable.xcstrings). Additional languages can be added through the localization and language-selection setup without changing game rules. See [App presentation](Documentation/AppPresentation.md#language-and-preferences).

## Design Philosophy

The app is intentionally small and offline-first. There are no accounts, advertisements, analytics, virtual currencies, or reward systems. The goal is to make Tuppen easy to play on an iPhone while keeping the rules and character of the game at the center.

## Architecture

- `Tuppen/Domain` contains the authoritative Swift game engine, independent of SwiftUI. See [Game engine](Documentation/GameEngine.md).
- `Tuppen/AI` receives restricted player views containing only a bot's own hand and public information. `Tuppen/Application` orchestrates sessions and validates every action through the engine.
- `Tuppen/Persistence` saves versioned local checkpoints containing match state, random streams, and statistics. See [AI and persistence](Documentation/AIAndPersistence.md).
- `Tuppen/Presentation` renders public state and events, with presentation pacing that keeps turns and responses sequential. See [App presentation](Documentation/AppPresentation.md).

The project uses native Apple frameworks and has no third-party dependencies. Cards are drawn in SwiftUI. The original sound effects have [documented, reproducible synthesis sources](Documentation/Sound.md).

## Requirements

- iPhone running iOS 18 or later; gameplay is portrait-oriented.
- macOS with Xcode and an iOS SDK supporting the deployment target.
- Swift 6 language mode, as configured in the project.

Debug and Release simulator builds and the non-UI test suite have been verified with **Xcode 27.0**. Compatibility with older Xcode versions has not been established; 27.0 is the tested version, not a claimed minimum.

## Building

1. Clone the repository and open `Tuppen.xcodeproj` in Xcode.
2. Select the shared **Tuppen** scheme and an iPhone simulator or device.
3. For device builds, select the **Tuppen** app target and choose your own Apple Development Team under **Signing & Capabilities**, if needed.
4. Change the bundle identifier locally if Xcode requires a unique identifier. Apply corresponding local signing overrides to the test target when testing on a device.
5. Build and run.

No third-party dependencies need to be installed. The checked-in team and bundle identifiers identify the maintainer's signing configuration; they are not credentials or secrets and may need local overrides. Keep personal signing changes out of unrelated contributions.

To build for the simulator from the command line:

```sh
xcodebuild -project Tuppen.xcodeproj -scheme Tuppen \
  -configuration Debug -destination 'generic/platform=iOS Simulator' build
```

Use `-configuration Release` to check the release configuration.

## Testing

The Swift Testing suite covers game rules, AI legality and hidden information, persistence, statistics, application/session behavior, and presentation sequencing.

List installed destinations, then run all non-UI tests with an available iPhone simulator ID:

```sh
xcodebuild -project Tuppen.xcodeproj -scheme Tuppen -showdestinations
xcodebuild -project Tuppen.xcodeproj -scheme Tuppen \
  -destination 'platform=iOS Simulator,id=SIMULATOR_ID' \
  -only-testing:TuppenTests test
```

Automated UI tests are intentionally not part of the project at this time. UI, accessibility interaction, sound, and haptic quality are checked manually using the [verification checklist](Documentation/AppPresentation.md#manual-verification).

## Privacy

Gameplay works offline and requires no account. The app has no analytics, advertising, tracking, or custom backend. Game progress, statistics, and preferences are stored locally; there is no app-managed cloud synchronization.

The bundled [privacy manifest](Tuppen/PrivacyInfo.xcprivacy) declares app-only preference storage through `UserDefaults` using reason `CA92.1`, with no tracking or collected data. Optional multiplayer through Apple Game Center / GameKit is a future roadmap item and is not included in V1.

## Roadmap

V1 is the current implementation. Later versions are plans without a release schedule.

### V1

Polished offline Tuppen against computer opponents.

### V2

Selectable number of computer opponents.

### V3

Selectable AI difficulty.

### V4

Regional and house-rule configuration under the idea: *So spielen wir.*

### V5

Private multiplayer using Apple Game Center / GameKit.

## Contributing

Read the [repository development guidance](AGENTS.md) and [product specification](PRODUCT_SPEC.md) before making changes.

Use English for source-code identifiers, comments, test names, and repository documentation. German and English are the current UI localizations. Keep game rules in the engine rather than SwiftUI, and include non-UI regression tests for rule changes. Useful comments are encouraged around non-obvious rules, state transitions, and architectural decisions.

Build the app and run the non-UI suite before submitting changes. Automated UI tests are intentionally not required; follow the manual verification guidance for presentation changes.

## License

TUPPEN is available under the [MIT License](LICENSE). This includes the original source code and bundled sound effects. The sounds use no external samples; their provenance is documented in [Table sound and haptics](Documentation/Sound.md#asset-origin).
