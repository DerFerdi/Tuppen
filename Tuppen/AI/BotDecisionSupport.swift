/// Shared interpretation of public decision windows, without assigning tactics
/// or reconstructing legal actions. Each strategy still owns its risk policy.
enum BotDecisionSupport {
    static func mayAct(in view: PlayerView) -> Bool {
        guard view.matchPhase == .playing || view.matchPhase == .eightCardRule,
              !view.legalActions.isEmpty else { return false }
        let expected: PlayerID?
        switch view.roundPhase {
        case .playing(let turn): expected = turn.player
        case .awaitingResponses(let pending): expected = pending.expectedResponder
        case .awaitingPovertyResponses(let pending): expected = pending.expectedResponder
        case .awaitingFourPicturesChallenges(let pending): expected = pending.expectedResponder
        case .finished: expected = nil
        }
        return expected == view.player
    }

    static func finalTrick(in view: PlayerView) -> Int { view.isEightCardRule ? 8 : 4 }

    static func legalCards(in view: PlayerView) -> [Card] {
        view.legalActions.compactMap { action -> Card? in
            if case .playCard(let card) = action { card } else { nil }
        }.sorted {
            $0.rank == $1.rank ? $0.suit.rawValue < $1.suit.rawValue : $0.rank < $1.rank
        }
    }

    static func strokes(of player: PlayerID, in view: PlayerView) -> Int {
        view.players.first { $0.id == player }?.strokes ?? 0
    }

    static func knownFalseClaim(by player: PlayerID, in view: PlayerView) -> Bool {
        // Historical revelations do not prove what a replacement hand contains.
        view.knownHands.contains { $0.player == player && $0.cards.contains { !$0.isPicture } }
    }

    static func previouslyExposedBluff(by player: PlayerID, in view: PlayerView) -> Bool {
        view.revealedHands.contains { $0.player == player && !$0.cards.isFourPictures }
    }

    static func weakExchangeCandidate(_ hand: [Card]) -> Bool {
        // Exchanging a single Seven with three low pictures can help; throwing
        // away several numbered cards rarely justifies the challenge risk.
        hand.count == 4 && hand.filter { !$0.isPicture }.count == 1
            && hand.allSatisfy { $0.rank <= .seven }
            && hand.reduce(0) { $0 + $1.rank.rawValue } <= 8
    }
}
