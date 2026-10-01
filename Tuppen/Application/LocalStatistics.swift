/// Lifetime counters for the human seat. Statistics are saved alongside the
/// session checkpoint, but never form part of the authoritative rules state.
struct LocalStatistics: Codable, Equatable, Sendable {
    private(set) var matchesPlayed = 0
    private(set) var matchesWon = 0
    private(set) var roundsPlayed = 0
    private(set) var roundsWon = 0
    private(set) var knocksMade = 0
    private(set) var knocksHeld = 0
    private(set) var knocksPassed = 0
    private(set) var highestStakeReached = 0

    mutating func record(_ events: [GameEvent], state: MatchState, human: PlayerID) throws {
        for event in events {
            switch event {
            case .matchWon(let winner):
                try increment(&matchesPlayed)
                if winner == human { try increment(&matchesWon) }
            case .matchDrawn:
                try increment(&matchesPlayed)
            // Hand entries survive Pass and final scoring, including empty
            // hands. They identify who was dealt into this particular round.
            case .roundEnded(let outcome) where state.round.hands[human] != nil:
                try increment(&roundsPlayed)
                if outcome.winner == human { try increment(&roundsWon) }
            case .playerKnocked(let player, _) where player == human:
                try increment(&knocksMade)
            case .playerHeld(let player) where player == human:
                try increment(&knocksHeld)
            case .playerPassed(let player) where player == human:
                try increment(&knocksPassed)
            default: break
            }
        }
        // The post-action participant list excludes a player who just passed.
        // Include that boundary action, but ignore every later bot-only raise.
        if !events.isEmpty,
           state.round.participants.contains(human) || events.contains(.playerPassed(human)) {
            highestStakeReached = max(highestStakeReached, state.round.stake)
        }
    }

    func validate() throws {
        let counts = [matchesPlayed, matchesWon, roundsPlayed, roundsWon, knocksMade, knocksHeld, knocksPassed]
        guard counts.allSatisfy({ $0 >= 0 }), matchesWon <= matchesPlayed,
              roundsWon <= roundsPlayed,
              (0...33).contains(highestStakeReached) else { throw PersistenceError.invalidContents }
    }
}

private func increment(_ value: inout Int) throws {
    let (next, overflow) = value.addingReportingOverflow(1)
    guard !overflow else { throw SessionError.statisticsOverflow }
    value = next
}
