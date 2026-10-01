/// A strategy receives one seat's restricted view and a decision-only random
/// stream. It returns intent without choosing an actor or mutating authority.
protocol BotStrategy: Sendable {
    func chooseAction<R: RandomNumberGenerator>(from view: PlayerView, using random: inout R) -> GameAction?
}

/// A deliberately imperfect strategy: preserve strength early, seek the final
/// lead, and weigh a raise against visible strength and elimination risk.
struct V1BotStrategy: BotStrategy {
    func chooseAction<R: RandomNumberGenerator>(from view: PlayerView, using random: inout R) -> GameAction? {
        guard view.matchPhase == .playing, !view.legalActions.isEmpty else { return nil }
        let expected: PlayerID?
        switch view.roundPhase {
        case .playing(let turn): expected = turn.player
        case .awaitingResponses(let pending): expected = pending.expectedResponder
        case .finished: expected = nil
        }
        guard expected == view.player else { return nil }

        let confidence = positionStrength(view)
        let strokes = view.players.first { $0.id == view.player }?.strokes ?? 0
        if view.legalActions.contains(.respondToKnock(.hold)) {
            // Prefer holding over immediate elimination when the heuristic is
            // positive. A nonpositive estimate does not prove a loss is certain.
            let passEliminates = strokes + view.stake - 1 >= 7
            let threshold = 0.35 + min(0.25, Double(view.stake - 1) * 0.04)
            let response: KnockResponse = (passEliminates && confidence > 0) || confidence >= threshold ? .hold : .pass
            let action = GameAction.respondToKnock(response)
            return view.legalActions.contains(action) ? action : view.legalActions.first
        }
        if view.legalActions.contains(.knock), confidence >= 0.55 {
            let chance = confidence >= 0.85 ? 65 : 8
            if random.next() % 100 < chance { return .knock }
        }
        let cards = view.legalActions.compactMap { action -> Card? in
            if case .playCard(let card) = action { card } else { nil }
        }.sorted { lhs, rhs in
            lhs.rank == rhs.rank ? lhs.suit.rawValue < rhs.suit.rawValue : lhs.rank < rhs.rank
        }
        guard let weakest = cards.first else { return nil }
        let winners = cards.filter { card in
            var trick = view.currentTrick
            trick.append(PlayedCard(player: view.player, card: card))
            return trick.winningPlay?.player == view.player
        }
        if view.currentTrick.number == 4, !winners.isEmpty {
            let waiting = view.players.filter { player in
                player.isParticipating && player.id != view.player
                    && !view.currentTrick.plays.contains { $0.player == player.id }
            }
            // Last to act can win cheaply; otherwise use the strongest legal
            // winner because there is no later trick worth saving it for.
            return .playCard(waiting.isEmpty ? winners[0] : winners[winners.count - 1])
        }
        if view.currentTrick.number == 3,
           let leadCard = winners.first(where: { candidate in
               view.hand.contains { $0 != candidate && cardStrength($0, view: view) >= 0.75 }
           }) {
            return .playCard(leadCard)
        }
        return .playCard(weakest)
    }

    private func positionStrength(_ view: PlayerView) -> Double {
        if view.currentTrick.number == 4,
           let committed = view.currentTrick.plays.first(where: { $0.player == view.player }) {
            guard view.currentTrick.winningPlay?.player == view.player else { return 0 }
            return cardStrength(committed.card, view: view)
        }
        var candidates = view.hand
        if view.currentTrick.number == 4, let lead = view.leadSuit {
            let followers = candidates.filter { $0.suit == lead }
            if !followers.isEmpty { candidates = followers }
            candidates = candidates.filter { card in
                var trick = view.currentTrick
                trick.append(PlayedCard(player: view.player, card: card))
                return trick.winningPlay?.player == view.player
            }
        }
        let strength = candidates.map { cardStrength($0, view: view) }.max() ?? 0
        let opponents = view.players.filter { $0.isParticipating && $0.id != view.player }.count
        return strength - Double(max(0, opponents - 1)) * 0.06
    }

    private func cardStrength(_ card: Card, view: PlayerView) -> Double {
        let publicCards = view.completedTricks.flatMap { $0.trick.plays.map(\.card) }
            + view.currentTrick.plays.map(\.card)
        let known = Set(publicCards + view.hand)
        let higherUnseen = Rank.allCases.filter {
            $0 > card.rank && !known.contains(Card(suit: card.suit, rank: $0))
        }.count
        // Unseen higher cards may be undealt; this is a rough strength estimate,
        // not an inference about any particular opponent's hidden hand.
        return 1 - Double(higherUnseen) / 7
    }
}
