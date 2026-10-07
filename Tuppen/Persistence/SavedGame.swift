/// Authoritative match state and the independent streams needed to continue its
/// deals and decisions. No presentation state or live strategy object is saved.
struct SavedSession: Codable, Equatable, Sendable {
    let human: PlayerID
    var match: MatchState
    var deckRandom: SeededRandom
    var botRandom: SeededRandom
    let botCount: BotCount
    let difficulty: BotDifficulty

    init(
        human: PlayerID, match: MatchState, deckRandom: SeededRandom,
        botRandom: SeededRandom, botCount: BotCount = .two, difficulty: BotDifficulty = .medium
    ) {
        self.human = human
        self.match = match
        self.deckRandom = deckRandom
        self.botRandom = botRandom
        self.botCount = botCount
        self.difficulty = difficulty
    }

    private enum CodingKeys: String, CodingKey {
        case human, match, deckRandom, botRandom, botCount, difficulty
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        human = try values.decode(PlayerID.self, forKey: .human)
        match = try values.decode(MatchState.self, forKey: .match)
        deckRandom = try values.decode(SeededRandom.self, forKey: .deckRandom)
        botRandom = try values.decode(SeededRandom.self, forKey: .botRandom)
        // Version-1 saves predate this field and always had two bots. Default
        // only for an absent key: null or invalid counts remain corrupt data.
        botCount = try values.contains(.botCount) ? values.decode(BotCount.self, forKey: .botCount) : .two
        // Historical decisions used V1, now Medium. An explicit invalid value
        // must fail instead of silently changing a saved match's strategy.
        difficulty = try values.contains(.difficulty) ? values.decode(BotDifficulty.self, forKey: .difficulty) : .medium
    }
}

struct SavedGame: Codable, Equatable, Sendable {
    var statistics = LocalStatistics()
    var session: SavedSession?

    func restoredEngine() throws -> GameEngine? {
        try statistics.validate()
        guard let session else { return nil }
        guard session.match.players.count == session.botCount.playerCount,
              session.match.players.contains(where: { $0.id == session.human }) else {
            throw PersistenceError.invalidContents
        }
        // Counters may have been reset mid-match, and stake tracking stops on
        // Pass. Neither rounds played nor highest stake must cover this state.
        do {
            return try GameEngine(restoring: session.match)
        } catch {
            throw PersistenceError.invalidContents
        }
    }
}

/// Error cases carry meaning rather than UI text. Presentation can translate
/// these cases without putting localized strings into the rules or save format.
enum PersistenceError: Error, Equatable {
    case unsupportedVersion(Int)
    case corruptData
    case invalidContents
    case readFailed
    case writeFailed
    case removalFailed
}
