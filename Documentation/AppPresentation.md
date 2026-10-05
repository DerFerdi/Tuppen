# App presentation

The app opens on Home. New Game creates one human and two opponents; Continue appears only after a valid active match loads. Replacing an unfinished match requires one confirmation and keeps lifetime statistics. How to Play, Statistics, and Settings use native navigation. Terminal matches remain saved but do not offer Continue.

## Session boundary

`SessionDriver` is an actor that exclusively owns `GameSession` and its store. Calls perform synchronous engine work, bot decisions, and disk writes on that actor, away from the main actor. The existing session still validates and saves every action before publication; the engine, bot strategy, statistics semantics, and version-1 save format are unchanged.

The adapter returns `SessionUpdate`: the human's `PlayerView`, local statistics, public events, and round stroke changes. It never returns `MatchState`, an engine, opponent hands, undealt cards, or random streams. SwiftUI renders the supplied phases and legal actions. It does not calculate turn order, follow-suit permissions, winners, scoring, or elimination.

`AppModel` is a main-actor observable model. It owns navigation, busy state, recovery alerts, the latest committed update, and a disposable `TablePresentation`. Views submit intentions through it. A busy guard serializes commands and disables action controls while a transaction or required presentation sequence is running. The engine remains the final validator.

New Game records the current navigation intent before asynchronous work begins. A successful save always publishes its session, but opens the table only if that request is still current and has not been cancelled. Navigation during the save keeps its destination; the committed match remains available through Continue.

## Automatic play and round results

After a human action, one owned task in `AppModel` presents its accepted events, then requests automatic steps from the driver. A bot has a thinking beat before its action is submitted. Each successful save publishes the authoritative update immediately, then `TableTimeline` produces ordered public frames. The next bot cannot begin until those frames have finished. Human input remains disabled throughout the required sequence.

`TablePacing` centralizes timing: 0.5 seconds for a bot card decision, 0.65 for a Knock response, 0.3 for card movement, and 0.18 to settle. A completed trick remains readable, highlights the engine-reported winning card for 0.8 seconds, then collects. Fourth-trick outcomes appear before stroke increments and elimination. Each Hold/Pass response has a separate 0.8-second beat near its player. Tests inject a clock, so no wall-clock delays or device feedback are needed for sequencing checks.

`SessionDriver.advance()` still stops at a finished round. Next Round acknowledges the compact result while the human remains in the match. An eliminated human has no round decision: the presentation waits briefly at each result and automatically requests the next deal until a winner or draw is reached. Match results offer New Game and Home.

After human elimination, Skip to Result appears in the table's top controls until the match finishes. It cancels and awaits the owned presentation task, then runs the same automatic-play loop without pauses or intermediate effects. Each bot action and deal still uses the existing transactional driver; no engine, scoring, or persistence shortcut is involved. The table stays still with a small progress indicator until the real result appears, which VoiceOver announces once. Navigation/backgrounding cancels the request after any in-flight save settles. Save failures retain the last checkpoint and Retry resumes fast-forward from there. The skip preference is temporary and is not saved.

Stroke changes compare current totals with the round start reconstructed by the engine's existing restoration helper. This includes earlier Pass penalties and works after relaunch without keeping a second scoring implementation or persisting a presentation recap. Restore never replays these changes into statistics.

The timeline retains completed public tricks while the engine has already advanced logically. Cards committed by passed players remain visible and can receive winner emphasis. It never compares cards to decide a winner. Earlier player totals are held visually until the corresponding scoring event; elimination follows its stroke change. Only restricted player views and public events enter these frames.

Navigation away from the table or backgrounding cancels the owned task, stops effects, and discards unfinished choreography. A save already in flight is still published. The table settles to the latest checkpoint; returning resumes future work without replaying historical events. A quick return waits for cancelled work to finish before another task starts. An ordinary navigation callback does not queue extra work or automatically retry a save failure. No animation state, delays, highlights, or effects are persisted.

## Table and interaction

The game uses a bounded `GeometryReader` composition, with no scrolling table or hand. Opponent seats stay fixed, card backs show remaining counts, and seven narrow stroke marks stay beside each player. The bottom hand adapts its width and overlap to the available portrait space. The central trick receives the remaining height. Compact result layouts replace the trick and hand instead of adding another panel below them. Practical Dynamic Type limits keep the table bounded; full VoiceOver labels retain the information represented visually.

A reserved interaction region below the trick holds Hold/Pass, Knock, hints, and transient status text. Its height remains the same when empty, and hand sizing depends only on available height. Shorter portrait layouts use tighter spacing to retain room for the trick without shrinking the hand when a response appears.

Permanent history, round/trick counters, verbose turn prompts, and the navigation title are removed. A quiet menu retains Settings, Statistics, and an explicit Knock action. The stake appears when raised or when a response is required. Temporary reactions and scoring deltas appear near their seats.

Double tapping the table submits Knock only when the engine advertises it and presentation is idle. A successful saved Knock triggers two separate sound/haptic taps 0.14 seconds apart, a restrained table reaction, and TOK TOK; its raised stake is then revealed. Bot Knocks use the same sequence with lighter haptics. Hold/Pass controls appear only after that sequence and preceding bot responses finish. A restored response prompt names the knocker and stake without replaying sound. VoiceOver has an explicit button and named accessibility action; the menu action is available without the gesture too.

## Recovery

A failed save keeps the last committed display and checkpoint. Retry repeats the failed command. If an automatic step fails after a successful human action or earlier bot step, retry resumes automatic work instead of submitting the human action again. A dismissed automatic error leaves a Retry button on the game screen.

A failed restore leaves Home safe, hides Continue, and offers a localized explanation. Dismissing the alert leaves a Retry button beside the Home recovery message. `AppModel.retryRestore()` uses the same load command and session driver; it remains available after repeated failures, including a failed new-game replacement. Successful loading removes the recovery message without rewriting the checkpoint or recounting statistics. Corrupt and unsupported files remain untouched until New Game explicitly replaces the unreadable checkpoint after a successful save; statistics in an unreadable file cannot be recovered through that path. Statistics reset uses the existing atomic session operation and updates the display only on success. Technical details are logged in debug builds, not shown to players.

## Language and preferences

`AppPreferences` stores language, sound, and haptics in `UserDefaults`, separately from match data. System chooses among supported language preferences, with English as fallback. Deutsch and English select their language explicitly. Sound and haptics are independently checked for every timeline cue; see [Table sound and haptics](Sound.md) for the native service and original asset provenance.

`GameStrings` resolves `Localizable.xcstrings` through the selected compiled language bundle, including interpolated names and card accessibility labels. The same locale is supplied to SwiftUI for formatting. Catalog entries are maintained for both English and German. Unused Swift symbol generation is disabled so compact format keys such as scoring deltas need not become Swift identifiers. Changing language updates presentation without restarting the session or writing the game file. Stable seat IDs determine opponent numbering, including after elimination.

Cards use native rank text and suit symbols with red/black ink. VoiceOver labels name the full rank and suit; unavailable card buttons remain disabled, and legal cards have an action hint. Player summaries combine names, labeled strokes, and participation status. Reduce Motion replaces card travel, fan angles, lifts, and table scaling with fades or static emphasis. It shortens decorative movement and thinking beats while preserving readable response and scoring beats. Layout, larger text sizes, full accessibility behavior, and physical feedback still need manual review.

## Tutorial and accessibility

How to Play is an optional eight-section guide: cards, rank order, following suit, the fourth trick, strokes, Knock, Hold, and Pass. It reuses native card and stroke views, emphasizes the fourth trick, and leaves rare cases to the rules reference. The guide scrolls and wraps at all text sizes; its illustrations duplicate the prose and are hidden from VoiceOver. Home can scroll when large text or recovery messages need more room. Result actions stack when they cannot fit horizontally. The game table retains its fixed interaction region and controlled typography without scrolling.

VoiceOver traverses navigation, opponents, the current trick, the decision, the hand, and the human summary. The trick is one semantic item in play order rather than spatial order. Player summaries read actual strokes against the seven-stroke threshold, participation, and relevant turn status. Card values distinguish playable cards from unavailable cards, explaining the led suit when the engine rejects a card during a card turn. Hold/Pass hints explain the stake and Pass penalty. The ordinary Knock button, menu action, and named accessibility action all use the same engine-derived legality gate; the custom table gesture is inactive while VoiceOver is enabled.

Each meaningful `GameEvent` is attached to exactly one `TableBeat`. `AppModel` waits for both the existing visual beat and `TableAnnouncements` before advancing; decorative taps, collection, and frame settlement add no speech. `NativeTableAnnouncements` posts localized, low-priority speech with the selected language and observes Apple's [announcement completion notification](https://developer.apple.com/documentation/uikit/uiaccessibility/announcementdidfinishnotification). Interrupted speech is not repeated. Navigation and backgrounding discard pending work; disabling VoiceOver releases the wait and continues normal play. A centralized 15-second fallback prevents a missing system callback from stranding a turn. Restoring a checkpoint never replays historical events. A brief current-action prompt marks the return to human input. Sound and haptic preferences do not affect announcements.

Accessibility text uses the same string catalog as visible text, including native plural rules for stroke penalties. Human and opponent sentences have separate keys where grammar differs. Adding a language requires catalog translations, its `AppLanguage` preference/support entry, and Xcode localization registration; game state and rules do not change. Prominent buttons use contrasting text in both appearances. Suit shapes, card ranks, outlines, stroke fills, and winner checkmarks retain meaning without color or motion.

Non-UI tests cover localized descriptions and plurals, tutorial content, completion/interruption/cancellation of speech with injected notifications, response ordering, language changes during speech, VoiceOver being disabled mid-turn, and unchanged saved bytes after language switches. They do not operate or inspect an accessibility UI tree.

## Manual verification

- On small and large portrait iPhones, confirm four cards, both opponents, strokes, and contextual Hold/Pass fit without scrolling. Check English/German and light/dark appearance.
- Play a trick: each bot card should arrive separately, all cards should remain readable, the winner should be emphasized, and collection should precede the next lead. Check a passed player's committed winning card too.
- Double tap to Knock: two distinct taps, TOK TOK, raised stake, then separate Hold/Pass reactions. Check an illegal double tap is silent and the accessible Knock alternatives work.
- Watch fourth-trick outcome, stroke deltas, elimination, and results in that order. An eliminated human should not need Next Round. Check winner and Draw presentation when reached.
- After human elimination, use Skip to Result during a bot turn and between rounds. Check the quiet progress indicator and final result in both languages and with VoiceOver. Leave or background during skipping, then return; only committed progress should remain and normal pacing should resume.
- Background or leave during a card move, between Knock taps, during scoring, and during a bot thinking beat; return and confirm no duplicate action or stale effect. Terminate/relaunch with a pending human response and with a completed round.
- Toggle Sound and Haptics independently, check silent mode and music playback, and enable Reduce Motion. Judge material quality, volume, pacing, and haptics on an iPhone.
- Switch language during a match, reset statistics with and without confirming, and replace a match. Review larger text and VoiceOver card, stroke, player, and action labels. Visual verification is manual; no UI automation or snapshot tests are used.
- After a restore failure, dismiss the alert and check that Home's Retry remains reachable in both languages and with VoiceOver. A successful retry should restore Continue and remove the recovery message; repeated failures must leave the saved file intact.
- Read How to Play in both languages at standard and largest text sizes. Confirm all eight sections are understandable, rank order is clear, and Back returns to Home without starting or replacing a match.
- With VoiceOver, play a complete match using the explicit Knock control. Follow a forced-suit turn, a pending Hold/Pass response, scoring, elimination, and a terminal result with Sound and Haptics off. Check speech speed, interruption by focus gestures, and return from Settings/backgrounding. Confirm actual reading order and button hit targets on a device.
- At large text sizes, check Home, Hold/Pass, round/match result actions, Statistics, and Settings in both appearances. Check prominent-button text contrast and Reduce Motion winner emphasis without relying on color.
