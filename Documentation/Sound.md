# Table sound and haptics

The table timeline sends `TableEffect` cues to `NativeTableEffects`. Audio and haptics are independently gated at each cue using the current preferences. Views, the engine, bots, and persistence do not play effects. A Knock cue contains one tap; the timeline schedules the second tap so sound, haptics, and the visible response share the same timing and cancellation.

Playback uses `AVAudioPlayer` with an ambient audio session. It respects the iPhone's silent switch and mixes with other audio. Audio failures are nonfatal. Leaving the table or backgrounding stops playing sounds and deactivates the session; there are no queued callbacks in the effect service to resume later. UIKit feedback generators provide short impacts, with a lighter opponent Knock and a stronger human Knock. Card placement and trick wins use subtle feedback; dealing and collecting have no haptic. Larger stroke penalties increase impact intensity within a fixed bound. Elimination has one distinct impact, and a human match win uses a success notification.

## Asset origin

All six WAVs in `Tuppen/Resources/Sounds` are original procedural effects made for this repository. `Tools/generate_sounds.py` contains their complete source, uses only Python's standard library, and reproduces the checked-in files with fixed noise seeds. There are no recordings, downloaded samples, external synthesis models, or third-party audio dependencies. No third-party attribution or sample license applies. These assets are project material; this document does not assign a separate license to the repository.

The sounds are intentionally restrained synthesized interpretations of paper contact and a solid tabletop, not recordings of real materials. They are provisional original assets pending listening and tuning on an iPhone. The Knock combines a short filtered-noise contact with damped, inharmonic resonances. Each asset is mono 44.1 kHz, 16-bit PCM, with short endpoint fades and conservative peak levels. Playback further reduces gain to 65 percent. The match result is a quiet pair of card contacts, without a musical victory cue.

Regenerate from the repository root:

```sh
python3 Tools/generate_sounds.py
```

| File | Duration | Cue |
| --- | --- | --- |
| `card-dealt.wav` | 120 ms | New round |
| `card-placed.wav` | 160 ms | Committed card placement |
| `table-knock.wav` | 125 ms | One Knock tap |
| `trick-collected.wav` | 230 ms | Trick collection |
| `stroke-added.wav` | 100 ms | Stroke increment |
| `match-result.wav` | 320 ms | Match conclusion |

## Verification

Non-UI tests exercise independent preference gates, cue routing, single-tap Knock behavior, bounded stroke feedback, stop forwarding, and bundled audio decoding. They use an injected output recorder and never play sound or haptics.

Judge the final tactile quality on an iPhone: two distinct Knock taps, modest volume relative to music, silent-mode behavior, independent Sound/Haptics switches, no sound after backgrounding, and restrained feedback for scoring and elimination. Simulator playback cannot establish physical haptic quality or speaker balance.
