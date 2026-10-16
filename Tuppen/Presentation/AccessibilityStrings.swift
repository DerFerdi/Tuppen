import Foundation

extension GameStrings {
    func strokes(_ count: Int, maximum: MaximumStrokes = .seven) -> String {
        switch maximum {
        case .seven: text("\(count) of seven strokes")
        case .ten: text("\(count) of ten strokes")
        }
    }

    func cardAvailability(_ card: Card, in view: PlayerView, busy: Bool) -> String {
        if busy { return text("Currently unavailable") }
        if view.legalActions.contains(.playCard(card)) { return text("Playable") }
        // The engine has already decided which cards follow suit. Explain its
        // rejection only during a card turn; do not infer new legal actions.
        if view.legalActions.contains(where: { if case .playCard = $0 { true } else { false } }),
           let suit = view.leadSuit {
            return text("Follow \(self.suit(suit)).")
        }
        return text("Currently unavailable")
    }

    func actionPrompt(in view: PlayerView) -> String {
        switch view.roundPhase {
        case .playing(let turn):
            return turn.player == view.player ? text("Your turn. Play a card.")
                : text("\(player(turn.player, in: view)) to play.")
        case .awaitingResponses(let pending):
            if pending.expectedResponder == view.player {
                return text("Your response. Hold or Pass. Stake: \(view.stake).")
            }
            if let responder = pending.expectedResponder {
                return text("Waiting for \(player(responder, in: view)) to Hold or Pass.")
            }
            return text("Stake: \(view.stake)")
        case .awaitingPovertyResponses(let pending):
            if pending.expectedResponder == view.player {
                return text("Your response. Hold or Pass. Stake: \(view.stake).")
            }
            if let responder = pending.expectedResponder {
                return text("Waiting for \(player(responder, in: view)) to Hold or Pass.")
            }
            return text("Stake: \(view.stake)")
        case .awaitingFourPicturesChallenges(let pending):
            if pending.expectedResponder == view.player {
                return challengePrompt(in: view) + " " + text("Your response. Challenge or Decline.")
            }
            if let responder = pending.expectedResponder {
                return text("Waiting for \(player(responder, in: view)) to Challenge or Decline.")
            }
            return challengePrompt(in: view)
        case .finished(let outcome):
            return view.matchPhase.isActive ? roundResult(outcome, in: view) : matchResult(in: view)
        }
    }

    func matchResult(in view: PlayerView) -> String {
        switch view.matchPhase {
        case .playing, .awaitingEightCardDeal, .eightCardRule: text("The opponents play on.")
        case .finished(let winner):
            winner == view.player ? text("You win the match.") : text("\(player(winner, in: view)) wins the match.")
        case .draw: text("The match is a draw.")
        }
    }

    func announcement(_ event: GameEvent, in view: PlayerView) -> String {
        switch event {
        case .roundStarted(let number, _): text("Round \(number). Cards dealt.")
        case .cardPlayed(let play):
            play.player == view.player ? text("You played \(card(play.card)).")
                : text("\(player(play.player, in: view)) played \(card(play.card)).")
        case .playerKnocked(let id, let stake):
            id == view.player ? text("You knocked. Stake: \(stake).")
                : text("\(player(id, in: view)) knocked. Stake: \(stake)")
        case .playerHeld(let id):
            id == view.player ? text("You Hold.") : text("\(player(id, in: view)) Holds.")
        case .playerPassed(let id):
            id == view.player ? text("You Pass.") : text("\(player(id, in: view)) Passes.")
        case .trickWon(let number, let winner):
            text("Trick \(number) · Winner: \(player(winner, in: view))")
        case .roundEnded(let outcome): roundResult(outcome, in: view)
        case .strokesAdded(let id, let amount):
            text("\(player(id, in: view)): \(text("\(amount) strokes added."))")
        case .playerEliminated(let id):
            id == view.player ? text("You are eliminated.") : text("\(player(id, in: view)) is eliminated.")
        case .matchWon, .matchDrawn: matchResult(in: view)
        case .povertyStarted(let participants):
            text("Poverty. Stake: two. Poor players: \(participants.map { player($0, in: view) }.joined(separator: ", ")).")
        case .fourPicturesClaimed(let id):
            id == view.player ? text("You claim Four Pictures.")
                : text("\(player(id, in: view)) claims Four Pictures.")
        case .fourPicturesDeclined(let id):
            id == view.player ? text("You decline to challenge.")
                : text("\(player(id, in: view)) declines to challenge.")
        case .fourPicturesChallenged(let claimant, let challenger):
            if challenger == view.player { text("You challenge \(player(claimant, in: view)).") }
            else if claimant == view.player { text("\(player(challenger, in: view)) challenges your claim.") }
            else { text("\(player(challenger, in: view)) challenges \(player(claimant, in: view)).") }
        case .fourPicturesBluffExposed(let id):
            text("\(player(id, in: view)): bluff exposed.")
        case .fourPicturesRevealed(let hand):
            hand.player == view.player ? text("You reveal: \(hand.cards.map(card).joined(separator: ", ")).")
                : text("\(player(hand.player, in: view)) reveals: \(hand.cards.map(card).joined(separator: ", ")).")
        case .fourPicturesExchanged(let id):
            id == view.player ? text("You exchange four cards.")
                : text("\(player(id, in: view)) exchanges four cards.")
        case .eightCardRuleStarted:
            text("Eight-Card-Rule. Eight cards, eight tricks. Only the eighth trick decides the match.")
        case .eightCardRuleEnded(let winner, _):
            winner == view.player ? text("You win the eighth trick and the match.")
                : text("\(player(winner, in: view)) wins the eighth trick and the match.")
        }
    }

    func notice(_ notice: TableNotice, in view: PlayerView) -> String {
        switch notice {
        case .event(.fourPicturesRevealed(let hand)):
            hand.player == view.player ? text("You reveal your hand.")
                : text("\(player(hand.player, in: view)) reveals their hand.")
        case .event(let event): announcement(event, in: view)
        case .verifiedPictures(let player):
            text("\(self.player(player, in: view)): Four Pictures confirmed.")
        }
    }
}
