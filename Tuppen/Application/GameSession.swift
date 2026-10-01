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
    static let seats = (0..<3).map { PlayerID(rawValue: $0) }

    private let store: any GameStore
    private var saved: SavedGame
    private var engine: GameEngine?

    var state: MatchState? { engine?.state }
    var statistics: LocalStatistics { saved.statistics }
    var hasActiveMatch: Bool { engine?.state.phase == .playing }

    init(store: any GameStore) throws {
        self.store = store
        saved = try store.load() ?? SavedGame()
        engine = try saved.restoredEngine()
    }

    private init(emptyStore store: any GameStore) {
        self.store = store
        saved = SavedGame()
    }

    /// A future recovery flow may explicitly choose a new local profile after
    /// reporting a load error. Nothing is overwritten until a new match is saved.
    static func empty(store: any GameStore) -> GameSession {
        GameSession(emptyStore: store)
    }

    func humanView() throws -> PlayerView? {
        guard let engine, let session = saved.session else { return nil }
        return try engine.view(for: session.human)
    }

    @discardableResult
    func startNewMatch(seeds: SessionSeeds = .system(), deck: Deck? = nil) throws -> [GameEvent] {
        var deckRandom = SeededRandom(seed: seeds.deck)
        let start = try GameEngine.start(
            players: Self.seats, deck: deck ?? Deck.shuffled(using: &deckRandom)
        )
        let session = SavedSession(
            human: Self.human, match: start.engine.state, deckRandom: deckRandom,
            botRandom: SeededRandom(seed: seeds.decisions)
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
    func advanceOneAutomaticStep(using strategy: any BotStrategy = V1BotStrategy()) throws -> [GameEvent]? {
        guard var candidate = engine, var session = saved.session else { throw SessionError.noMatch }
        guard candidate.state.phase == .playing else { return nil }
        let events: [GameEvent]
        switch candidate.state.round.phase {
        case .finished:
            events = try candidate.startNextRound(deck: Deck.shuffled(using: &session.deckRandom))
        case .playing(let turn):
            guard turn.player != session.human else { return nil }
            events = try botAction(by: turn.player, engine: &candidate, session: &session, strategy: strategy)
        case .awaitingResponses(let pending):
            guard let responder = pending.expectedResponder else { throw SessionError.invalidBotAction }
            guard responder != session.human else { return nil }
            events = try botAction(by: responder, engine: &candidate, session: &session, strategy: strategy)
        }
        try commit(candidate, session: session, events: events)
        return events
    }

    func advanceBots(using strategy: any BotStrategy = V1BotStrategy(), maxActions: Int = 64) throws -> AutomaticProgress {
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
        by player: PlayerID, engine: inout GameEngine, session: inout SavedSession, strategy: any BotStrategy
    ) throws -> [GameEvent] {
        let view = try engine.view(for: player)
        guard let action = strategy.chooseAction(from: view, using: &session.botRandom),
              view.legalActions.contains(action) else { throw SessionError.invalidBotAction }
        return try engine.apply(action, by: player)
    }

    private func commit(_ candidate: GameEngine, session: SavedSession, events: [GameEvent]) throws {
        var next = saved
        var checkpoint = session
        checkpoint.match = candidate.state
        next.session = checkpoint
        try next.statistics.record(events, state: candidate.state, human: session.human)
        // Publish neither events nor state until both state and counters are on
        // disk. Restore reads counters directly and never consumes old events.
        try store.save(next)
        saved = next
        engine = candidate
    }
}
