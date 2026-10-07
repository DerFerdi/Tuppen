/// Bounded heuristics over the same public view used by every difficulty. Card
/// counting estimates threats; it never assigns exact hidden hands to opponents.
struct HardBotStrategy: BotStrategy {
    func chooseAction<R: RandomNumberGenerator>(from view: PlayerView, using random: inout R) -> GameAction? {
        guard view.matchPhase == .playing, !view.legalActions.isEmpty else { return nil }
        switch view.roundPhase {
        case .playing(let turn) where turn.player == view.player: break
        case .awaitingResponses(let pending) where pending.expectedResponder == view.player: break
        default: return nil
        }

        let position = PublicPosition(view)
        let confidence = position.roundConfidence
        let strokes = view.players.first { $0.id == view.player }?.strokes ?? 0
        if view.legalActions.contains(.respondToKnock(.hold)) {
            let passEliminates = strokes + view.stake - 1 >= 7
            let lossEliminates = strokes + view.stake >= 7
            // Compare accepting the raised stake with paying the old stake now.
            // A survivable Pass deserves extra weight when Hold risks elimination.
            let threshold = lossEliminates ? 0.68 : 1 / Double(view.stake) + 0.06
            let hold = passEliminates ? confidence > 0 : confidence >= threshold
            let action = GameAction.respondToKnock(hold ? .hold : .pass)
            return view.legalActions.contains(action) ? action : view.legalActions.first
        }

        if view.legalActions.contains(.knock) {
            let raisesEliminationRisk = strokes + view.stake < 7 && strokes + view.stake + 1 >= 7
            let threshold = 0.7 + (raisesEliminationRisk ? 0.16 : 0)
                + min(0.08, Double(view.stake - 1) * 0.02)
            if confidence >= 0.999 { return .knock }
            if confidence >= threshold, random.next() % 100 < 60 { return .knock }
        }

        let cards = view.legalActions.compactMap { action -> Card? in
            if case .playCard(let card) = action { card } else { nil }
        }.sorted {
            $0.rank == $1.rank ? $0.suit.rawValue < $1.suit.rawValue : $0.rank < $1.rank
        }
        guard var chosen = cards.first else { return nil }
        var best = position.playValue(chosen)
        for card in cards.dropFirst() {
            let score = position.playValue(card)
            if score > best {
                chosen = card
                best = score
            }
        }
        return .playCard(chosen)
    }
}

private struct PublicPosition {
    let view: PlayerView
    let knownCards: Set<Card>
    let voidSuits: [PlayerID: Set<Suit>]
    let opponents: [PublicPlayerState]

    init(_ view: PlayerView) {
        self.view = view
        let tricks = view.completedTricks.map(\.trick) + [view.currentTrick]
        knownCards = Set(view.hand + tricks.flatMap { $0.plays.map(\.card) })
        opponents = view.players.filter { $0.isParticipating && $0.id != view.player }
        var voids: [PlayerID: Set<Suit>] = [:]
        for trick in tricks {
            guard let lead = trick.leadSuit else { continue }
            for play in trick.plays where play.card.suit != lead {
                // Mandatory following makes an off-suit play proof of a void.
                // Hands only shrink during a round, so that fact remains valid.
                voids[play.player, default: []].insert(lead)
            }
        }
        voidSuits = voids
    }

    var roundConfidence: Double {
        let strength: Double
        if view.currentTrick.number == 4 {
            if let committed = view.currentTrick.plays.first(where: { $0.player == view.player }) {
                strength = view.currentTrick.winningPlay?.player == view.player
                    ? unbeatenChance(committed.card, against: waitingOpponents) : 0
            } else {
                let followers = view.hand.filter { $0.suit == view.leadSuit }
                let candidates = followers.isEmpty ? view.hand : followers
                strength = candidates.map(finalWinChance).max() ?? 0
            }
        } else {
            let potentials = view.hand.map { unbeatenChance($0, against: opponents) }.sorted(by: >)
            guard let best = potentials.first else { return 0 }
            let backup = potentials.dropFirst().first ?? 0
            // A lone strong card is less valuable without another way to obtain
            // the final lead. This deliberately discounts early certainty.
            strength = best * (0.45 + 0.45 * backup)
        }
        guard strength > 0, strength < 1 else { return strength }
        // Holds and raises are weak signals, never proof of particular cards.
        // Departed players' aggression no longer represents an active threat.
        let active = Set(opponents.map(\.id))
        let raises = view.knocks.filter { active.contains($0.player) }.count
        let holds = view.knocks.flatMap(\.responses).filter {
            active.contains($0.player) && $0.response == .hold
        }.count
        return max(0.01, strength - min(0.12, Double(raises) * 0.025 + Double(holds) * 0.02))
    }

    func playValue(_ card: Card) -> Double {
        if view.currentTrick.number == 4 { return finalWinChance(card) }
        let remainder = view.hand.filter { $0 != card }
        let retainedStrength = remainder.map { unbeatenChance($0, against: opponents) }.max() ?? 0
        let lead = nextLeadChance(after: card)
        if view.currentTrick.number == 3 {
            // The last remaining card is much more useful when we choose its
            // suit as leader. Losing the lead retains a chance, not a guarantee.
            return retainedStrength * (0.42 + 0.58 * lead)
        }
        return retainedStrength - 0.18 * unbeatenChance(card, against: opponents) + 0.04 * lead
    }

    private var waitingOpponents: [PublicPlayerState] {
        opponents.filter { opponent in
            !view.currentTrick.plays.contains { $0.player == opponent.id }
        }
    }

    private func finalWinChance(_ card: Card) -> Double {
        var trick = view.currentTrick
        trick.append(PlayedCard(player: view.player, card: card))
        guard trick.winningPlay?.player == view.player else { return 0 }
        return unbeatenChance(card, against: waitingOpponents)
    }

    private func nextLeadChance(after card: Card) -> Double {
        var trick = view.currentTrick
        trick.append(PlayedCard(player: view.player, card: card))
        guard let winner = trick.winningPlay else { return 0 }
        let leader: PlayerID?
        if view.players.contains(where: { $0.id == winner.player && $0.isParticipating }) {
            leader = winner.player
        } else if let index = view.players.firstIndex(where: { $0.id == winner.player }) {
            // A passed winning card yields the next lead by fixed seating order.
            leader = (1...view.players.count).map { view.players[(index + $0) % view.players.count] }
                .first { $0.isParticipating }?.id
        } else {
            leader = nil
        }
        return leader == view.player ? unbeatenChance(winner.card, against: waitingOpponents) : 0
    }

    private func unbeatenChance(_ card: Card, against players: [PublicPlayerState]) -> Double {
        let higher = Rank.allCases.filter {
            $0 > card.rank && !knownCards.contains(Card(suit: card.suit, rank: $0))
        }.count
        guard higher > 0 else { return 1 }
        var chance = 1.0
        for player in players where !voidSuits[player.id, default: []].contains(card.suit) {
            let voids = voidSuits[player.id, default: []]
            let possibleCards = Suit.allCases.filter { !voids.contains($0) }.reduce(0) { total, suit in
                total + Rank.allCases.filter { !knownCards.contains(Card(suit: suit, rank: $0)) }.count
            }
            // Uniform unseen possibilities are a heuristic, not exact odds:
            // cards may be undealt and opponents' holdings are correlated.
            for draw in 0..<player.remainingCardCount {
                let available = possibleCards - draw
                guard available > 0 else { break }
                chance *= Double(max(0, available - higher)) / Double(available)
            }
        }
        return chance
    }
}
