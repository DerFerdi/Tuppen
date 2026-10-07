/// Simple rank-based play with occasional imperfect early discards. It never
/// infers missing suits or card locations from the public history.
struct EasyBotStrategy: BotStrategy {
    func chooseAction<R: RandomNumberGenerator>(from view: PlayerView, using random: inout R) -> GameAction? {
        guard view.matchPhase == .playing, !view.legalActions.isEmpty else { return nil }
        switch view.roundPhase {
        case .playing(let turn) where turn.player == view.player: break
        case .awaitingResponses(let pending) where pending.expectedResponder == view.player: break
        default: return nil
        }

        let strength = positionStrength(view)
        if view.legalActions.contains(.respondToKnock(.hold)) {
            let strokes = view.players.first { $0.id == view.player }?.strokes ?? 0
            let passEliminates = strokes + view.stake - 1 >= 7
            let threshold = min(0.8, 0.5 + Double(view.stake - 2) * 0.05)
            let response: KnockResponse = (passEliminates && strength > 0) || strength >= threshold ? .hold : .pass
            let action = GameAction.respondToKnock(response)
            return view.legalActions.contains(action) ? action : view.legalActions.first
        }

        if view.legalActions.contains(.knock), strength >= 0.85, view.stake <= 2,
           random.next() % 100 < 12 {
            return .knock
        }

        let cards = view.legalActions.compactMap { action -> Card? in
            if case .playCard(let card) = action { card } else { nil }
        }.sorted {
            $0.rank == $1.rank ? $0.suit.rawValue < $1.suit.rawValue : $0.rank < $1.rank
        }
        guard !cards.isEmpty else { return nil }
        if view.currentTrick.number == 4 {
            return .playCard(cards.last(where: { winsCurrentTrick($0, view: view) }) ?? cards[0])
        }
        // Choosing between the two cheapest cards gives away some lead control
        // without gratuitously throwing the strongest card from a full hand.
        return .playCard(cards[Int(random.next() % UInt64(min(2, cards.count)))])
    }

    private func positionStrength(_ view: PlayerView) -> Double {
        if view.currentTrick.number == 4,
           let committed = view.currentTrick.plays.first(where: { $0.player == view.player }) {
            return view.currentTrick.winningPlay?.player == view.player
                ? rankStrength(committed.card) : 0
        }
        let candidates = view.currentTrick.number == 4
            ? view.hand.filter { winsCurrentTrick($0, view: view) } : view.hand
        return candidates.map(rankStrength).max() ?? 0
    }

    private func rankStrength(_ card: Card) -> Double {
        // Even a Jack can win when led into opponents who cannot follow suit.
        Double(card.rank.rawValue + 1) / Double(Rank.allCases.count)
    }

    private func winsCurrentTrick(_ card: Card, view: PlayerView) -> Bool {
        if let lead = view.leadSuit, card.suit != lead, view.hand.contains(where: { $0.suit == lead }) {
            return false
        }
        var trick = view.currentTrick
        trick.append(PlayedCard(player: view.player, card: card))
        return trick.winningPlay?.player == view.player
    }
}
