/// Save validation uses the existing rules rather than maintaining a second
/// implementation of turns, passing, and scoring. Only the current round is
/// reconstructed; no match history or statistics are replayed.
extension GameEngine {
    func replaySavedRound(_ snapshot: MatchState) throws -> GameEngine {
        var engine = self
        let plays = snapshot.round.uniqueTricks.flatMap { trick in
            trick.plays.map { (trick.number, $0) }
        }
        var playIndex = 0
        var knockIndex = 0
        while playIndex < plays.count || knockIndex < snapshot.round.knocks.count {
            guard case .playing(let turn) = engine.state.round.phase else { throw GameError.invalidSavedState }
            if knockIndex < snapshot.round.knocks.count,
               snapshot.round.knocks[knockIndex].trickNumber == engine.state.round.currentTrick.number,
               snapshot.round.knocks[knockIndex].player == turn.player {
                let knock = snapshot.round.knocks[knockIndex]
                try engine.apply(.knock, by: knock.player)
                for response in knock.responses {
                    try engine.apply(.respondToKnock(response.response), by: response.player)
                }
                knockIndex += 1
            } else {
                guard playIndex < plays.count else { throw GameError.invalidSavedState }
                let (number, play) = plays[playIndex]
                guard number == engine.state.round.currentTrick.number else { throw GameError.invalidSavedState }
                try engine.apply(.playCard(play.card), by: play.player)
                playIndex += 1
            }
        }
        return engine
    }
}

private extension RoundState {
    /// The final resolved trick is also left on the table at round end.
    var uniqueTricks: [TrickState] {
        let completed = completedTricks.map(\.trick)
        return completed.last == currentTrick ? completed : completed + [currentTrick]
    }
}

extension MatchState {
    func roundStartForRestoration() throws -> MatchState {
        let seats = players.map(\.id)
        let dealtSeats = Set(round.hands.keys)
        // These bounds follow from a 32-card deck and seven-stroke elimination.
        // Check them before arithmetic or indexing on untrusted decoded values.
        let maxStake = 1 + seats.count * GameEngine.cardsPerPlayer
        guard (2...8).contains(seats.count), Set(seats).count == seats.count,
              (2...seats.count).contains(dealtSeats.count), dealtSeats.isSubset(of: Set(seats)),
              dealtSeats.contains(round.dealer),
              (1...(seats.count * GameEngine.eliminationStrokes)).contains(round.number),
              players.allSatisfy({ (0..<(GameEngine.eliminationStrokes + maxStake)).contains($0.strokes) }),
              (1...maxStake).contains(round.stake),
              round.knocks.count < maxStake, round.completedTricks.count <= 4,
              (1...4).contains(round.currentTrick.number),
              round.participants == seats.filter({ round.participants.contains($0) }),
              Set(round.participants).isSubset(of: dealtSeats), !round.participants.isEmpty,
              round.hands.values.allSatisfy({ $0.count <= 4 }), round.undealtCards.count <= 24 else {
            throw GameError.invalidSavedState
        }
        let tricks = round.uniqueTricks
        guard tricks.count <= 4 else { throw GameError.invalidSavedState }
        for (offset, trick) in tricks.enumerated() {
            guard trick.number == offset + 1, trick.plays.count <= dealtSeats.count,
                  Set(trick.plays.map(\.player)).count == trick.plays.count,
                  trick.plays.allSatisfy({ dealtSeats.contains($0.player) }),
                  trick.leadSuit == trick.plays.first?.card.suit else {
                throw GameError.invalidSavedState
            }
        }
        let committed = tricks.flatMap(\.plays)
        let cards = round.hands.values.flatMap { $0 } + committed.map(\.card) + round.undealtCards
        guard cards.count == 32, Set(cards) == Set(Deck.ordered.cards) else {
            throw GameError.invalidSavedState
        }
        var initialHands: [PlayerID: [Card]] = [:]
        for player in seats where dealtSeats.contains(player) {
            let hand = committed.filter { $0.player == player }.map(\.card) + round.hands[player, default: []]
            guard hand.count == 4 else { throw GameError.invalidSavedState }
            initialHands[player] = hand
        }
        var penalties: [PlayerID: Int] = [:]
        for (offset, knock) in round.knocks.enumerated() {
            guard dealtSeats.contains(knock.player), knock.previousStake == offset + 1,
                  (1...4).contains(knock.trickNumber), knock.responses.count < dealtSeats.count,
                  Set(knock.responses.map(\.player)).count == knock.responses.count,
                  knock.responses.allSatisfy({ dealtSeats.contains($0.player) }) else {
                throw GameError.invalidSavedState
            }
            for response in knock.responses where response.response == .pass {
                guard penalties[response.player] == nil else { throw GameError.invalidSavedState }
                penalties[response.player] = knock.previousStake
            }
        }
        if case .finished(let outcome) = round.phase {
            for player in round.participants where player != outcome.winner {
                guard penalties[player] == nil else { throw GameError.invalidSavedState }
                penalties[player] = round.stake
            }
        }
        var initialPlayers = players
        for index in initialPlayers.indices {
            initialPlayers[index].strokes -= penalties[initialPlayers[index].id, default: 0]
            let player = initialPlayers[index]
            guard player.strokes >= 0,
                  (player.status == .active) == dealtSeats.contains(player.id) else {
                throw GameError.invalidSavedState
            }
        }
        if round.number == 1, !initialPlayers.allSatisfy({ $0.strokes == 0 }) {
            throw GameError.invalidSavedState
        }
        // Every completed round adds at least one unit of scoring progress.
        // Cap each seat at elimination: an oversized last penalty cannot fund
        // extra rounds. Subtract this round's penalties before checking history.
        let priorProgress = initialPlayers.reduce(0) { $0 + min($1.strokes, GameEngine.eliminationStrokes) }
        guard round.number - 1 <= priorProgress else { throw GameError.invalidSavedState }
        let dealerIndex = seats.firstIndex(of: round.dealer)!
        let order = (1...seats.count).map { seats[(dealerIndex + $0) % seats.count] }
        let leader = order.first { dealtSeats.contains($0) }!
        return MatchState(players: initialPlayers, round: RoundState(
            number: round.number, dealer: round.dealer, participants: seats.filter { dealtSeats.contains($0) },
            hands: initialHands, undealtCards: round.undealtCards,
            phase: .playing(.mayKnock(leader)), currentTrick: TrickState(number: 1)
        ))
    }
}
