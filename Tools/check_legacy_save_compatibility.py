#!/usr/bin/env python3
"""Check the current writer against the actual committed pre-V4 reader.

Run `python3 Tools/check_legacy_save_compatibility.py` on macOS with Xcode and
the repository's Git history available. Sources, compiler caches, executables,
and checkpoints stay in a temporary directory. No simulator or UI is involved.
"""

from pathlib import Path
import subprocess
import tempfile


# Last implementation commit before House Rules, with V2 counts and V3 difficulty.
LEGACY_COMMIT = "d74a93f6df10879e43516b9b85052ffdfcb9639f"
SOURCE_ROOTS = ("Tuppen/Domain", "Tuppen/AI", "Tuppen/Application", "Tuppen/Persistence")

CURRENT_WRITER = r'''
import Foundation

struct DecliningBot: BotStrategy {
    func chooseAction<R: RandomNumberGenerator>(from view: PlayerView, using random: inout R) -> GameAction? {
        let decline = GameAction.respondToFourPictures(.decline)
        return view.legalActions.contains(decline) ? decline : nil
    }
}

let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let store = LocalGameStore(fileURL: directory.appendingPathComponent("working.json"))
let rules = try HouseRules(
    maximumStrokes: .ten, poverty: true, consecutiveKnockRestriction: true,
    fourPictures: true, fourPicturesBluffing: true, eightCardRule: true
)
let players = (0..<3).map { PlayerID(rawValue: $0) }
let start = try GameEngine.start(players: players, dealer: players.last, deck: .ordered, houseRules: rules)
try store.save(SavedGame(session: SavedSession(
    human: players[0], match: start.engine.state, deckRandom: SeededRandom(seed: 17),
    botRandom: SeededRandom(seed: 23), botCount: .two, difficulty: .hard
)))
let session = try GameSession(store: store)
let initialView = try session.humanView()
precondition(initialView?.hand.isFourPictures == false)
try session.submitHuman(.claimFourPictures)
let pending = try Data(contentsOf: store.fileURL)
try pending.write(to: directory.appendingPathComponent("pending-challenge.json"))

// Produce lifetime counters through a real accepted exchange, then carry them
// into an ordinary match: the version boundary must protect that profile too.
let progress = try session.advanceBots(using: DecliningBot())
precondition(progress.stop == .humanInput)
precondition(session.statistics.fourPicturesExchanges == 1)
precondition(session.statistics.fourPicturesBluffs == 1)
let configured = try Data(contentsOf: store.fileURL)
try configured.write(to: directory.appendingPathComponent("configured-exchange.json"))
try session.startNewMatch(
    seeds: SessionSeeds(deck: 29, decisions: 31), deck: .ordered
)
precondition(session.state?.houseRules == .standard)
precondition(session.statistics.fourPicturesExchanges == 1)
precondition(session.statistics.fourPicturesBluffs == 1)
let standard = try Data(contentsOf: store.fileURL)
try standard.write(to: directory.appendingPathComponent("standard-with-v4-statistics.json"))
let profile = try GameSaveCodec.encode(SavedGame(statistics: session.statistics))
try profile.write(to: directory.appendingPathComponent("statistics-only.json"))

for data in [pending, configured, standard, profile] {
    let header = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    precondition(header["version"] as? Int == 2, "Current writer must produce version 2")
    _ = try GameSaveCodec.decode(data)
}
print("PASS: current writer produced four valid version-2 checkpoints")
'''

LEGACY_READER = r'''
import Foundation

let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let controlURL = URL(fileURLWithPath: CommandLine.arguments[2])
let control = try GameSaveCodec.decode(Data(contentsOf: controlURL))
precondition(control.session != nil)
print("PASS: historical reader accepts the independent version-1 pending-Knock fixture")

for name in ["pending-challenge", "configured-exchange", "standard-with-v4-statistics", "statistics-only"] {
    let store = LocalGameStore(fileURL: directory.appendingPathComponent(name + ".json"))
    let before = try Data(contentsOf: store.fileURL)
    do {
        _ = try GameSession(store: store)
        fatalError("Historical reader silently accepted " + name)
    } catch PersistenceError.unsupportedVersion(2) {
        let after = try Data(contentsOf: store.fileURL)
        precondition(after == before, "Rejected loading must not rewrite the checkpoint")
        print("PASS: historical reader rejects " + name + " as unsupportedVersion(2), retaining bytes")
    }
}

// A deliberately unparseable payload proves rejection precedes payload decoding.
do {
    _ = try GameSaveCodec.decode(Data(#"{"version":2,"game":"unreadable payload"}"#.utf8))
    fatalError("Historical reader accepted an unsupported payload")
} catch PersistenceError.unsupportedVersion(2) {
    print("PASS: historical version guard runs before payload interpretation")
}

// An already-installed old binary still controls its own explicit recovery path.
// Demonstrate that limitation only on a disposable checkpoint, never user data.
let recoveryStore = LocalGameStore(fileURL: directory.appendingPathComponent("standard-with-v4-statistics.json"))
let recovery = GameSession.empty(store: recoveryStore)
try recovery.startNewMatch(seeds: SessionSeeds(deck: 37, decisions: 41), deck: .ordered)
let replacement = try Data(contentsOf: recoveryStore.fileURL)
let envelope = try JSONSerialization.jsonObject(with: replacement) as! [String: Any]
precondition(envelope["version"] as? Int == 1)
let game = envelope["game"] as! [String: Any]
let statistics = game["statistics"] as! [String: Any]
precondition(statistics["fourPicturesExchanges"] == nil)
print("LIMITATION: explicit legacy new-game recovery replaces the profile and drops unknown counters")
'''


def compile_program(root: Path, sources: list[Path], main: str, name: str) -> Path:
    directory = root / name
    directory.mkdir()
    main_path = directory / "main.swift"
    main_path.write_text(main, encoding="utf-8")
    executable = directory / name
    subprocess.run(
        ["xcrun", "--sdk", "macosx", "swiftc", "-swift-version", "6",
         "-module-cache-path", str(root / "module-cache"),
         *map(str, sources), str(main_path), "-o", str(executable)],
        check=True,
    )
    return executable


def main() -> None:
    repository = Path(__file__).resolve().parent.parent
    # Read immutable Git objects; never check out files or alter the user's ref.
    historical_paths = subprocess.check_output(
        ["git", "ls-tree", "-r", "--name-only", LEGACY_COMMIT, "--", *SOURCE_ROOTS],
        cwd=repository, text=True,
    ).splitlines()
    with tempfile.TemporaryDirectory(prefix="tuppen-legacy-reader-") as temporary:
        root = Path(temporary)
        historical_sources = []
        for relative in historical_paths:
            if not relative.endswith(".swift"):
                continue
            destination = root / "historical" / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(subprocess.check_output(
                ["git", "show", f"{LEGACY_COMMIT}:{relative}"], cwd=repository,
            ))
            historical_sources.append(destination)
        current_sources = sorted(
            path for source_root in SOURCE_ROOTS
            for path in (repository / source_root).rglob("*.swift")
        )
        current = compile_program(root, current_sources, CURRENT_WRITER, "current-writer")
        legacy = compile_program(root, historical_sources, LEGACY_READER, "historical-reader")
        checkpoints = root / "checkpoints"
        checkpoints.mkdir()
        print(f"Historical reader: {LEGACY_COMMIT}", flush=True)
        subprocess.run([str(current), str(checkpoints)], check=True)
        subprocess.run(
            [str(legacy), str(checkpoints),
             str(repository / "TuppenTests/Fixtures/version-1-pending-knock.json")],
            check=True,
        )


if __name__ == "__main__":
    main()
