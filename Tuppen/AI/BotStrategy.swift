/// A strategy receives one seat's restricted view and a decision-only random
/// stream. It returns intent without choosing an actor or mutating authority.
protocol BotStrategy: Sendable {
    func chooseAction<R: RandomNumberGenerator>(from view: PlayerView, using random: inout R) -> GameAction?
}

/// A deliberately imperfect strategy: preserve strength early, seek the final
/// lead, and weigh a raise against visible strength and elimination risk.
struct V1BotStrategy: BotStrategy {
    func chooseAction<R: RandomNumberGenerator>(from view: PlayerView, using random: inout R) -> GameAction? {
        guard BotDecisionSupport.mayAct(in: view) else { return nil }

        let confidence = positionStrength(view)
        let strokes = BotDecisionSupport.strokes(of: view.player, in: view)
        let maximumStrokes = view.houseRules.maximumStrokes.rawValue
        if view.legalActions.contains(.respondToPoverty(.hold)) {
            let passEliminates = strokes + 1 >= maximumStrokes
            let threshold = strokes + 2 >= maximumStrokes ? 0.60 : 0.39
            return .respondToPoverty((passEliminates && confidence > 0) || confidence >= threshold ? .hold : .pass)
        }
        if case .awaitingFourPicturesChallenges(let pending) = view.roundPhase {
            return challengeResponse(to: pending.claimant, view: view, using: &random)
        }
        if view.legalActions.contains(.claimFourPictures),
           view.hand.isFourPictures || shouldBluffFourPictures(view, using: &random) {
            return .claimFourPictures
        }
        if view.legalActions.contains(.respondToKnock(.hold)) {
            // Prefer holding over immediate elimination when the heuristic is
            // positive. A nonpositive estimate does not prove a loss is certain.
            let passEliminates = strokes + view.stake - 1 >= view.houseRules.maximumStrokes.rawValue
            let threshold = 0.35 + min(0.25, Double(view.stake - 1) * 0.04)
            let response: KnockResponse = (passEliminates && confidence > 0) || confidence >= threshold ? .hold : .pass
            let action = GameAction.respondToKnock(response)
            return view.legalActions.contains(action) ? action : view.legalActions.first
        }
        if view.legalActions.contains(.knock), confidence >= 0.55 {
            // Keep strong raises frequent, but make speculative Knocks rare.
            // Both confidence ranges still consume exactly one decision draw.
            let chance = confidence >= 0.85 ? 65 : 2
            if random.next() % 100 < chance { return .knock }
        }
        let cards = BotDecisionSupport.legalCards(in: view)
        guard let weakest = cards.first else { return nil }
        let winners = cards.filter { card in
            var trick = view.currentTrick
            trick.append(PlayedCard(player: view.player, card: card))
            return trick.winningPlay?.player == view.player
        }
        let finalTrick = BotDecisionSupport.finalTrick(in: view)
        if view.currentTrick.number == finalTrick, !winners.isEmpty {
            let waiting = view.players.filter { player in
                player.isParticipating && player.id != view.player
                    && !view.currentTrick.plays.contains { $0.player == player.id }
            }
            // Last to act can win cheaply; otherwise use the strongest legal
            // winner because there is no later trick worth saving it for.
            return .playCard(waiting.isEmpty ? winners[0] : winners[winners.count - 1])
        }
        if view.currentTrick.number == finalTrick - 1,
           let leadCard = winners.first(where: { candidate in
               view.hand.contains { $0 != candidate && cardStrength($0, view: view) >= 0.75 }
           }) {
            return .playCard(leadCard)
        }
        return .playCard(weakest)
    }

    private func positionStrength(_ view: PlayerView) -> Double {
        let finalTrick = BotDecisionSupport.finalTrick(in: view)
        if view.currentTrick.number == finalTrick,
           let committed = view.currentTrick.plays.first(where: { $0.player == view.player }) {
            guard view.currentTrick.winningPlay?.player == view.player else { return 0 }
            return cardStrength(committed.card, view: view)
        }
        var candidates = view.hand
        if view.currentTrick.number == finalTrick, let lead = view.leadSuit {
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
            + view.currentTrick.plays.map(\.card) + view.discardedPublicCards
        let known = Set(publicCards + view.hand)
        let higherUnseen = Rank.allCases.filter {
            $0 > card.rank && !known.contains(Card(suit: card.suit, rank: $0))
        }.count
        // Unseen higher cards may be undealt; this is a rough strength estimate,
        // not an inference about any particular opponent's hidden hand.
        return 1 - Double(higherUnseen) / 7
    }

    private func shouldBluffFourPictures<R: RandomNumberGenerator>(_ view: PlayerView, using random: inout R) -> Bool {
        let opponents = view.players.filter { $0.isParticipating && $0.id != view.player }.count
        guard BotDecisionSupport.weakExchangeCandidate(view.hand),
              !BotDecisionSupport.knownFalseClaim(by: view.player, in: view),
              BotDecisionSupport.strokes(of: view.player, in: view) + 2 < view.houseRules.maximumStrokes.rawValue,
              (1...2).contains(opponents) else { return false }
        // A separate, restrained wager from ordinary Knocking: more possible
        // challengers reduce the appeal of replacing a weak but untruthful hand.
        return random.next() % 100 < (opponents == 1 ? 2 : 1)
    }

    private func challengeResponse<R: RandomNumberGenerator>(
        to claimant: PlayerID, view: PlayerView, using random: inout R
    ) -> GameAction {
        if BotDecisionSupport.knownFalseClaim(by: claimant, in: view) {
            return .respondToFourPictures(.challenge)
        }
        let maximum = view.houseRules.maximumStrokes.rawValue
        let strokes = BotDecisionSupport.strokes(of: view.player, in: view)
        let claimantStrokes = BotDecisionSupport.strokes(of: claimant, in: view)
        guard strokes + 2 < maximum, claimantStrokes + 1 < maximum else {
            return .respondToFourPictures(.decline)
        }
        let chance = BotDecisionSupport.previouslyExposedBluff(by: claimant, in: view) ? 6 : 2
        return .respondToFourPictures(random.next() % 100 < chance ? .challenge : .decline)
    }
}
