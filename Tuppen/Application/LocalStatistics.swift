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
    private(set) var eightCardRulesPlayed = 0
    private(set) var eightCardRulesWon = 0
    private(set) var fourPicturesExchanges = 0
    private(set) var fourPicturesBluffs = 0

    init() {}

    mutating func record(
        _ events: [GameEvent], state: MatchState, human: PlayerID, previousState: MatchState? = nil
    ) throws {
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
            case .eightCardRuleEnded(let winner, let participants) where participants.contains(human):
                // Starting and restoring a tiebreak emit no completion event.
                // The session commits both counters with the terminal state.
                try increment(&eightCardRulesPlayed)
                if winner == human { try increment(&eightCardRulesWon) }
            case .fourPicturesExchanged(let player) where player == human:
                try increment(&fourPicturesExchanges)
                // Classify only the human's own replaced hand. This private
                // bookkeeping must never become a public verification event.
                if let hand = previousState?.round.hands[human],
                   !hand.isFourPictures {
                    try increment(&fourPicturesBluffs)
                }
            default: break
            }
        }
        // Include the action that removes the human through Pass or a challenge
        // penalty, but ignore later bot-only raises and every tiebreak transition.
        if !events.isEmpty, state.eightCardRule == nil,
           state.round.participants.contains(human) || events.contains(.playerPassed(human))
                || (previousState?.round.participants.contains(human) == true
                    && events.contains(.playerEliminated(human))) {
            highestStakeReached = max(highestStakeReached, state.round.stake)
        }
    }

    func validate() throws {
        let counts = [matchesPlayed, matchesWon, roundsPlayed, roundsWon, knocksMade, knocksHeld, knocksPassed,
                      eightCardRulesPlayed, eightCardRulesWon, fourPicturesExchanges, fourPicturesBluffs]
        guard counts.allSatisfy({ $0 >= 0 }), matchesWon <= matchesPlayed,
              roundsWon <= roundsPlayed,
              // Tiebreak completion and its match result share one transaction;
              // resetting counters clears both, even during an active tiebreak.
              eightCardRulesPlayed <= matchesPlayed, eightCardRulesWon <= matchesWon,
              eightCardRulesWon <= eightCardRulesPlayed, fourPicturesBluffs <= fourPicturesExchanges,
              (0...33).contains(highestStakeReached) else { throw PersistenceError.invalidContents }
    }
}

private func increment(_ value: inout Int) throws {
    let (next, overflow) = value.addingReportingOverflow(1)
    guard !overflow else { throw SessionError.statisticsOverflow }
    value = next
}
