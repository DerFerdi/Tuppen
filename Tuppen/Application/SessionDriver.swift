import Foundation

struct StrokeChange: Equatable, Sendable {
    let player: PlayerID
    let amount: Int
}

/// The only session data crossing into presentation: one restricted view and
/// public results. Neither authoritative hands nor deal randomness leave here.
struct SessionUpdate: Equatable, Sendable {
    let view: PlayerView?
    let statistics: LocalStatistics
    let events: [GameEvent]
    let roundChanges: [StrokeChange]
}

/// Serializes the synchronous session and its disk writes off the main actor.
/// Each call remains a single transaction; presentation decides when to request
/// another step, and never receives the underlying GameSession.
actor SessionDriver {
    private var store: (any GameStore)?
    private var session: GameSession?

    init() {}

    init(store: sending any GameStore) {
        self.store = store
    }

    func load() throws -> SessionUpdate {
        if session == nil { session = try GameSession(store: resolvedStore()) }
        return try update()
    }

    func newMatch(
        botCount: BotCount = .two, seeds: SessionSeeds = .system(), deck: Deck? = nil
    ) throws -> SessionUpdate {
        // A user explicitly starting over can recover from an unreadable save.
        // Publish the replacement only after its first checkpoint succeeds.
        let candidate = try session ?? GameSession.empty(store: resolvedStore())
        let events = try candidate.startNewMatch(botCount: botCount, seeds: seeds, deck: deck)
        session = candidate
        return try update(events: events)
    }

    func submit(_ action: GameAction) throws -> SessionUpdate {
        guard let session else { throw SessionError.noMatch }
        return try update(events: session.submitHuman(action))
    }

    /// An explicit continuation acknowledges the displayed round result. Normal
    /// bot progression cannot silently deal over that result, including on load.
    func nextRound() throws -> SessionUpdate {
        guard let session else { throw SessionError.noMatch }
        guard case .finished = session.state?.round.phase else { throw GameError.roundNotFinished }
        guard session.hasActiveMatch else { throw GameError.matchFinished }
        return try update(events: session.advanceOneAutomaticStep() ?? [])
    }

    func advance(using strategy: any BotStrategy = V1BotStrategy()) throws -> SessionUpdate? {
        guard let session else { return nil }
        if case .finished = session.state?.round.phase { return nil }
        guard let events = try session.advanceOneAutomaticStep(using: strategy) else { return nil }
        return try update(events: events)
    }

    func resetStatistics() throws -> SessionUpdate {
        guard let session else { throw SessionError.noMatch }
        try session.resetStatistics()
        return try update()
    }

    private func resolvedStore() throws -> any GameStore {
        if let store { return store }
        let local = try LocalGameStore.applicationSupport()
        store = local
        return local
    }

    private func update(events: [GameEvent] = []) throws -> SessionUpdate {
        guard let session else { throw SessionError.noMatch }
        var changes: [StrokeChange] = []
        if let state = session.state, case .finished = state.round.phase {
            // The engine's existing reconstruction includes Pass penalties and
            // terminal scoring. Comparing totals avoids a second scoring rule
            // implementation, and also supplies a recap after relaunch.
            let start = try state.roundStartForRestoration()
            changes = zip(start.players, state.players).map {
                StrokeChange(player: $1.id, amount: $1.strokes - $0.strokes)
            }
        }
        return try SessionUpdate(
            view: session.humanView(), statistics: session.statistics,
            events: events, roundChanges: changes
        )
    }
}
