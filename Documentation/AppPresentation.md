# App presentation

The app opens on Home. New Game creates one human and two opponents; Continue appears only after a valid active match loads. Replacing an unfinished match requires one confirmation and keeps lifetime statistics. Statistics and Settings use native navigation. Terminal matches remain saved but do not offer Continue.

## Session boundary

`SessionDriver` is an actor that exclusively owns `GameSession` and its store. Calls perform synchronous engine work, bot decisions, and disk writes on that actor, away from the main actor. The existing session still validates and saves every action before publication; the engine, bot strategy, statistics semantics, and version-1 save format are unchanged.

The adapter returns `SessionUpdate`: the human's `PlayerView`, local statistics, public events, and round stroke changes. It never returns `MatchState`, an engine, opponent hands, undealt cards, or random streams. SwiftUI renders the supplied phases and legal actions. It does not calculate turn order, follow-suit permissions, winners, scoring, or elimination.

`AppModel` is a main-actor observable model. It owns navigation, busy state, recovery alerts, and the latest committed update. Views submit intentions through it. A busy guard serializes commands and disables action controls while a transaction or automatic sequence is running.

## Automatic play and round results

After a human action, one loop in `AppModel` requests automatic steps from the driver. Each successful step publishes a fresh update and yields cooperatively. The loop stops for human card input or a human Knock response, a completed round, or a terminal match. Navigation away from the game, backgrounding, or task cancellation stops before another transaction; an already successful transaction is still published. Returning to the game or foreground resumes eligible work.

`SessionDriver.advance()` deliberately stops at a finished round. Next Round acknowledges the result and explicitly requests the next deal. This also preserves a saved round result after relaunch. An eliminated human has no player actions; the bots continue between these same round-result pauses until a winner or draw is reached.

Stroke changes compare current totals with the round start reconstructed by the engine's existing restoration helper. This includes earlier Pass penalties and works after relaunch without keeping a second scoring implementation or persisting a presentation recap. Restore never replays these changes into statistics.

The current trick renders every committed public card, even if its owner has passed. The latest completed trick and Knock responses remain visible in the round history; an expandable history shows all public plays and responses for that round. This keeps quick bot decisions inspectable without introducing timing rules.

## Recovery

A failed save keeps the last committed display and checkpoint. Retry repeats the failed command. If an automatic step fails after a successful human action or earlier bot step, retry resumes automatic work instead of submitting the human action again. A dismissed automatic error leaves a Retry button on the game screen.

A corrupt or unsupported save leaves Home safe, hides Continue, and offers a localized explanation. Retry attempts loading again. New Game explicitly replaces the unreadable checkpoint only after a successful save; statistics in an unreadable file cannot be recovered through that path. Statistics reset uses the existing atomic session operation and updates the display only on success. Technical details are logged in debug builds, not shown to players.

## Language and preferences

`AppPreferences` stores language, sound, and haptics in `UserDefaults`, separately from match data. System chooses among supported language preferences, with English as fallback. Deutsch and English select their language explicitly. Sound and haptics are persisted preferences only; effects are not implemented yet.

`GameStrings` resolves `Localizable.xcstrings` through the selected compiled language bundle, including interpolated names and card accessibility labels. The same locale is supplied to SwiftUI for formatting. Catalog entries are maintained for both English and German. Changing language updates presentation without restarting the session or writing the game file. Stable seat IDs determine opponent numbering, including after elimination.

Cards use native rank text and suit symbols with red/black ink. VoiceOver labels name the full rank and suit; unavailable card buttons remain disabled, and legal cards have an action hint. Native buttons expose Knock, Hold, and Pass. Player summaries combine names, labeled strokes, and participation status. Layout, larger text sizes, and full accessibility behavior still need manual review.

## Manual verification

- Launch, start a match, and check four human cards, two opponents, strokes, stake, and turn prompts. Play a legal card and confirm unavailable cards cannot be played.
- Knock, inspect ordered bot responses, then play. Respond Hold and Pass to bot Knocks. Check passed cards stay visible while their trick is pending, and inspect completed tricks in Round History.
- Continue through round results, stroke changes, elimination, and match completion. If the human is eliminated first, use Next Round to continue the remaining bot match. Check winner/draw presentation when reached.
- Return Home during a match, Continue, and repeat after terminating and relaunching the app. Include a pending human response and a completed round awaiting acknowledgment.
- Open Statistics and Settings. Switch System/Deutsch/English during a match and confirm the hand and position remain intact. Relaunch to check language, sound, and haptic preferences.
- Cancel and confirm statistics reset; confirm the active match survives. Cancel replacement of an active match, then start another game.
- Review smaller iPhone sizes, light/dark appearance, larger text, and VoiceOver card/action/stroke labels. Visual verification is manual; no UI automation or snapshot tests are used.
