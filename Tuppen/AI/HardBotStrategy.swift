/// Bounded heuristics over the same public view used by every difficulty. Card
/// counting estimates threats; it never assigns exact hidden hands to opponents.
struct HardBotStrategy: BotStrategy {
    func chooseAction<R: RandomNumberGenerator>(from view: PlayerView, using random: inout R) -> GameAction? {
        guard BotDecisionSupport.mayAct(in: view) else { return nil }

        let position = PublicPosition(view)
        let confidence = position.roundConfidence
        let strokes = view.players.first { $0.id == view.player }?.strokes ?? 0
        let maximumStrokes = view.houseRules.maximumStrokes.rawValue
        if view.legalActions.contains(.respondToPoverty(.hold)) {
            let passEliminates = strokes + 1 >= maximumStrokes
            let lossEliminates = strokes + 2 >= maximumStrokes
            let pressureAfterPass = strokes + 1 >= maximumStrokes - 2
            // Paying one stroke safely can still leave little room next round.
            // Immediate elimination remains a stronger reason to avoid Hold.
            let threshold = lossEliminates ? 0.68 : 0.50 - (pressureAfterPass ? 0.08 : 0)
            let openingControl = opensRound(view) ? 0.05 : 0
            let hold = passEliminates ? confidence > 0 : confidence + openingControl >= threshold
            return .respondToPoverty(hold ? .hold : .pass)
        }
        if case .awaitingFourPicturesChallenges(let pending) = view.roundPhase {
            return challengeResponse(to: pending.claimant, view: view, using: &random)
        }
        if view.legalActions.contains(.claimFourPictures),
           view.hand.isFourPictures || shouldBluffFourPictures(view, confidence: confidence, using: &random) {
            return .claimFourPictures
        }
        if view.legalActions.contains(.respondToKnock(.hold)) {
            let passEliminates = strokes + view.stake - 1 >= maximumStrokes
            let lossEliminates = strokes + view.stake >= maximumStrokes
            // Compare accepting the raised stake with paying the old stake now.
            // A survivable Pass deserves extra weight when Hold risks elimination.
            let threshold = lossEliminates ? 0.68 : 1 / Double(view.stake) + 0.06
            let hold = passEliminates ? confidence > 0 : confidence >= threshold
            let action = GameAction.respondToKnock(hold ? .hold : .pass)
            return view.legalActions.contains(action) ? action : view.legalActions.first
        }

        if view.legalActions.contains(.knock) {
            let raisesEliminationRisk = strokes + view.stake < maximumStrokes
                && strokes + view.stake + 1 >= maximumStrokes
            let threshold = 0.7 + (raisesEliminationRisk ? 0.16 : 0)
                + min(0.08, Double(view.stake - 1) * 0.02)
            if confidence >= 0.999 { return .knock }
            if confidence >= threshold, random.next() % 100 < 60 { return .knock }
        }

        let cards = BotDecisionSupport.legalCards(in: view)
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

    private func opensRound(_ view: PlayerView) -> Bool {
        guard let dealer = view.players.firstIndex(where: { $0.id == view.dealer }) else { return false }
        let first = (1...view.players.count).map { view.players[(dealer + $0) % view.players.count] }
            .first { $0.isParticipating }
        return first?.id == view.player
    }

    private func shouldBluffFourPictures<R: RandomNumberGenerator>(
        _ view: PlayerView, confidence: Double, using random: inout R
    ) -> Bool {
        let opponents = view.players.filter { $0.isParticipating && $0.id != view.player }
        let maximum = view.houseRules.maximumStrokes.rawValue
        guard BotDecisionSupport.weakExchangeCandidate(view.hand), confidence <= 0.42,
              !BotDecisionSupport.knownFalseClaim(by: view.player, in: view),
              picturesUnavailable(to: view.player, view: view, includingOwnHand: false) <= 12,
              BotDecisionSupport.strokes(of: view.player, in: view) + 2 < maximum,
              (1...2).contains(opponents.count),
              opponents.allSatisfy({ $0.strokes >= maximum - 2 }) else { return false }
        // Pressure makes an uncertain challenge costly for every opponent. Even
        // then, replacing a weak hand is a rare wager, never routine aggression.
        return random.next() % 100 < (opponents.count == 1 ? 2 : 1)
    }

    private func challengeResponse<R: RandomNumberGenerator>(
        to claimant: PlayerID, view: PlayerView, using random: inout R
    ) -> GameAction {
        // Sixteen picture cards exist; thirteen known elsewhere rule out four
        // in the claimant’s hand without inspecting any hidden cards.
        if BotDecisionSupport.knownFalseClaim(by: claimant, in: view)
            || picturesUnavailable(to: claimant, view: view) > 12 {
            return .respondToFourPictures(.challenge)
        }
        let maximum = view.houseRules.maximumStrokes.rawValue
        let strokes = BotDecisionSupport.strokes(of: view.player, in: view)
        let claimantStrokes = BotDecisionSupport.strokes(of: claimant, in: view)
        // A past exposed bluff is a weak behavioral signal after an exchange,
        // not proof about the new hand. Do not risk elimination on that signal.
        guard strokes + 2 < maximum, claimantStrokes + 1 < maximum,
              BotDecisionSupport.previouslyExposedBluff(by: claimant, in: view) else {
            return .respondToFourPictures(.decline)
        }
        return .respondToFourPictures(random.next() % 100 < 4 ? .challenge : .decline)
    }

    private func picturesUnavailable(
        to claimant: PlayerID, view: PlayerView, includingOwnHand: Bool = true
    ) -> Int {
        let played = (view.completedTricks.map(\.trick) + [view.currentTrick]).flatMap { $0.plays.map(\.card) }
        let heldElsewhere = view.knownHands.filter { $0.player != claimant }.flatMap(\.cards)
        // A challenge can use our private cards. Before bluffing ourselves, only
        // publicly unavailable cards prove what opponents can already disprove.
        let ownCards = includingOwnHand ? view.hand : []
        return Set(ownCards + played + view.discardedPublicCards + heldElsewhere).filter(\.isPicture).count
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
        knownCards = Set(view.hand + tricks.flatMap { $0.plays.map(\.card) }
            + view.discardedPublicCards + view.knownHands.flatMap(\.cards))
        opponents = view.players.filter { $0.isParticipating && $0.id != view.player }
        var voids: [PlayerID: Set<Suit>] = [:]
        for trick in tricks {
            guard let lead = trick.leadSuit else { continue }
            for play in trick.plays where play.card.suit != lead {
                // Mandatory following makes an off-suit play proof of a void.
                // Exchanges are possible only before a seat's first card, so
                // a void proved by its own play cannot later be refilled.
                voids[play.player, default: []].insert(lead)
            }
        }
        voidSuits = voids
    }

    var roundConfidence: Double {
        let strength: Double
        if view.currentTrick.number == BotDecisionSupport.finalTrick(in: view) {
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
        let finalTrick = BotDecisionSupport.finalTrick(in: view)
        if view.currentTrick.number == finalTrick { return finalWinChance(card) }
        let remainder = view.hand.filter { $0 != card }
        let retained = remainder.map { unbeatenChance($0, against: opponents) }.sorted(by: >)
        let retainedStrength = retained.first ?? 0
        let lead = nextLeadChance(after: card)
        if view.currentTrick.number == finalTrick - 1 {
            // The last remaining card is much more useful when we choose its
            // suit as leader. Losing the lead retains a chance, not a guarantee.
            return retainedStrength * (0.42 + 0.58 * lead)
        }
        // A longer tiebreak needs an entry as well as a final winner. Preserve a
        // second control card early instead of protecting only the best card.
        let entryReserve = view.isEightCardRule ? 0.22 * (retained.dropFirst().first ?? 0) : 0
        return retainedStrength + entryReserve - 0.18 * unbeatenChance(card, against: opponents) + 0.04 * lead
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
        var chance = 1.0
        for player in players where !voidSuits[player.id, default: []].contains(card.suit) {
            let retained = view.knownHands.first { $0.player == player.id }?.cards ?? []
            if retained.contains(where: { $0.suit == card.suit && $0.rank > card.rank }) { return 0 }
            guard higher > 0 else { continue }
            let voids = voidSuits[player.id, default: []]
            let possibleCards = Suit.allCases.filter { !voids.contains($0) }.reduce(0) { total, suit in
                total + Rank.allCases.filter { !knownCards.contains(Card(suit: suit, rank: $0)) }.count
            }
            // Uniform unseen possibilities are a heuristic, not exact odds:
            // cards may be undealt and opponents' holdings are correlated.
            for draw in 0..<max(0, player.remainingCardCount - retained.count) {
                let available = possibleCards - draw
                guard available > 0 else { break }
                chance *= Double(max(0, available - higher)) / Double(available)
            }
        }
        return chance
    }
}
