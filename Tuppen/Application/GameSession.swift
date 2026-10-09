struct SessionSeeds: Sendable {
    let deck: UInt64
    let decisions: UInt64

    static func system() -> SessionSeeds {
        var random = SystemRandomNumberGenerator()
        return SessionSeeds(deck: random.next(), decisions: random.next())
    }
}

enum SessionError: Error, Equatable {
    case noMatch
    case invalidBotAction
    case invalidActionBudget
    case statisticsOverflow
}

enum AutomaticStop: Equatable, Sendable {
    case humanInput
    case matchFinished
    /// A cooperative work budget expired. Calling advanceBots again resumes play.
    case yielded
}

struct AutomaticProgress: Equatable, Sendable {
    let events: [GameEvent]
    let stop: AutomaticStop
}

/// A single owner serializes calls to this non-UI application service. Each
/// successful action commits its state, random streams, and counters together.
/// Failed writes leave the live session unchanged and can be retried safely.
final class GameSession {
    static let human = PlayerID(rawValue: 0)

    private let store: any GameStore
    private var saved: SavedGame
    private var engine: GameEngine?

    var state: MatchState? { engine?.state }
    var statistics: LocalStatistics { saved.statistics }
    var hasActiveMatch: Bool { engine?.state.phase.isActive == true }
    var botCount: BotCount? { saved.session?.botCount }
    var difficulty: BotDifficulty? { saved.session?.difficulty }
    var houseRules: HouseRules? { engine?.state.houseRules }

    init(store: any GameStore) throws {
        self.store = store
        saved = try store.load() ?? SavedGame()
        engine = try saved.restoredEngine()
    }

    private init(emptyStore store: any GameStore) {
        self.store = store
        saved = SavedGame()
    }

    /// The recovery flow may explicitly choose a new local profile after
    /// reporting a load error. Nothing is overwritten until a new match is saved.
    static func empty(store: any GameStore) -> GameSession {
        GameSession(emptyStore: store)
    }

    func humanView() throws -> PlayerView? {
        guard let engine, let session = saved.session else { return nil }
        return try engine.view(for: session.human)
    }

    @discardableResult
    func startNewMatch(
        botCount: BotCount = .two, difficulty: BotDifficulty = .medium,
        houseRules: HouseRules = .standard,
        seeds: SessionSeeds = .system(), deck: Deck? = nil
    ) throws -> [GameEvent] {
        var deckRandom = SeededRandom(seed: seeds.deck)
        // Seat zero remains the human; every other stable ID is a bot. Seats
        // remain in this order throughout the match, including after elimination.
        let seats = (0..<botCount.playerCount).map { PlayerID(rawValue: $0) }
        let start = try GameEngine.start(
            players: seats, deck: deck ?? Deck.shuffled(using: &deckRandom), houseRules: houseRules
        )
        let session = SavedSession(
            human: Self.human, match: start.engine.state, deckRandom: deckRandom,
            botRandom: SeededRandom(seed: seeds.decisions), botCount: botCount, difficulty: difficulty
        )
        try commit(start.engine, session: session, events: start.events)
        return start.events
    }

    @discardableResult
    func submitHuman(_ action: GameAction) throws -> [GameEvent] {
        guard var candidate = engine, let session = saved.session else { throw SessionError.noMatch }
        let events = try candidate.apply(action, by: session.human)
        try commit(candidate, session: session, events: events)
        return events
    }

    /// Processes one bot intention or one between-round deal. The expected actor
    /// comes from the engine's phase, including its sequential response queue.
    /// nil means human input or a terminal match, never an artificial delay.
    @discardableResult
    func advanceOneAutomaticStep(using strategy: (any BotStrategy)? = nil) throws -> [GameEvent]? {
        guard var candidate = engine, var session = saved.session else { throw SessionError.noMatch }
        guard candidate.state.phase.isActive else { return nil }
        let events: [GameEvent]
        if case .awaitingEightCardDeal = candidate.state.phase {
            events = try candidate.startEightCardRule(deck: Deck.shuffled(using: &session.deckRandom))
        } else if candidate.state.phase == .playing, case .finished = candidate.state.round.phase {
            events = try candidate.startNextRound(deck: Deck.shuffled(using: &session.deckRandom))
        } else {
            guard let actor = candidate.expectedActor else { throw SessionError.invalidBotAction }
            guard actor != session.human else { return nil }
            events = try botAction(by: actor, engine: &candidate, session: &session, strategy: strategy)
        }
        try commit(candidate, session: session, events: events)
        return events
    }

    func advanceBots(using strategy: (any BotStrategy)? = nil, maxActions: Int = 64) throws -> AutomaticProgress {
        guard maxActions > 0 else { throw SessionError.invalidActionBudget }
        var events: [GameEvent] = []
        for _ in 0..<maxActions {
            guard let next = try advanceOneAutomaticStep(using: strategy) else {
                return AutomaticProgress(events: events, stop: hasActiveMatch ? .humanInput : .matchFinished)
            }
            events += next
        }
        return AutomaticProgress(events: events, stop: .yielded)
    }

    func resetStatistics() throws {
        var next = saved
        next.statistics = LocalStatistics()
        try store.save(next)
        saved = next
    }

    private func botAction(
        by player: PlayerID, engine: inout GameEngine, session: inout SavedSession, strategy: (any BotStrategy)?
    ) throws -> [GameEvent] {
        // Test scenarios may inject a strategy. Standard decisions, including
        // after restore or Skip to Result, use the saved match's difficulty.
        let view = try engine.view(for: player)
        let action: GameAction?
        if let strategy {
            action = strategy.chooseAction(from: view, using: &session.botRandom)
        } else if view.legalActions.contains(.respondToPoverty(.hold)) {
            // The backend's neutral policy accepts Poverty and declines optional
            // challenges. Strategic House Rules decisions belong in a later pass.
            action = .respondToPoverty(.hold)
        } else if view.legalActions.contains(.respondToFourPictures(.decline)) {
            action = .respondToFourPictures(.decline)
        } else if view.matchPhase == .eightCardRule {
            // Existing difficulties reason about four-card rounds. Until they
            // support the tiebreak, use a deterministic engine-approved card.
            action = view.legalActions.first
        } else {
            action = session.difficulty.makeStrategy().chooseAction(from: view, using: &session.botRandom)
        }
        guard let action, view.legalActions.contains(action) else { throw SessionError.invalidBotAction }
        return try engine.apply(action, by: player)
    }

    private func commit(_ candidate: GameEngine, session: SavedSession, events: [GameEvent]) throws {
        var next = saved
        var checkpoint = session
        checkpoint.match = candidate.state
        next.session = checkpoint
        try next.statistics.record(events, state: candidate.state, human: session.human, previousState: engine?.state)
        // Publish neither events nor state until both state and counters are on
        // disk. Restore reads counters directly and never consumes old events.
        try store.save(next)
        saved = next
        engine = candidate
    }
}
