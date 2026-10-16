import Foundation

protocol GameStore {
    func load() throws -> SavedGame?
    /// Implementations must replace the checkpoint atomically or leave it intact.
    func save(_ game: SavedGame) throws
}

enum GameSaveCodec {
    // This boundary also protects lifetime counters in standard-rules matches
    // and statistics-only profiles from readers that predate House Rules.
    static let currentVersion = 2

    private struct Header: Decodable {
        let version: Int
    }

    private struct Envelope: Codable {
        let version: Int
        let game: SavedGame
    }

    static func encode(_ game: SavedGame) throws -> Data {
        _ = try game.restoredEngine()
        return try JSONEncoder().encode(Envelope(version: currentVersion, game: game))
    }

    static func decode(_ data: Data) throws -> SavedGame {
        let decoder = JSONDecoder()
        let version: Int
        do { version = try decoder.decode(Header.self, from: data).version }
        catch { throw PersistenceError.corruptData }
        guard version == 1 || version == currentVersion else {
            throw PersistenceError.unsupportedVersion(version)
        }
        let game: SavedGame
        do {
            // Compatibility defaults belong to the old wire format, not to the
            // current models. Loading never writes the migrated value to disk.
            let currentData = version == 1 ? try VersionOneMigration.apply(to: data) : data
            game = try decoder.decode(Envelope.self, from: currentData).game
        }
        catch { throw PersistenceError.corruptData }
        _ = try game.restoredEngine()
        return game
    }
}

/// One local file contains both match and statistics, so a crash cannot save a
/// counted event without its corresponding match state (or the reverse).
struct LocalGameStore: GameStore {
    let fileURL: URL

    init(fileURL: URL) { self.fileURL = fileURL }

    static func applicationSupport() throws -> LocalGameStore {
        do {
            let directory = try FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
            ).appendingPathComponent("Tuppen", isDirectory: true)
            return LocalGameStore(fileURL: directory.appendingPathComponent("game.json"))
        } catch { throw PersistenceError.readFailed }
    }

    func load() throws -> SavedGame? {
        let data: Data
        do { data = try Data(contentsOf: fileURL) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return nil }
        catch { throw PersistenceError.readFailed }
        return try GameSaveCodec.decode(data)
    }

    func save(_ game: SavedGame) throws {
        let data = try GameSaveCodec.encode(game)
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: .atomic)
        } catch { throw PersistenceError.writeFailed }
    }

    /// Explicit recovery only: a failed load never deletes or replaces evidence.
    func remove() throws {
        do { try FileManager.default.removeItem(at: fileURL) }
        catch let error as CocoaError where error.code == .fileNoSuchFile { return }
        catch { throw PersistenceError.removalFailed }
    }
}
