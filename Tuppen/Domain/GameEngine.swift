/// The sole authority for rules and scoring. The engine is a value type with no
/// UI dependencies or ambient randomness. Rejected actions leave state unchanged.
struct GameEngine: Sendable {
    static let cardsPerPlayer = 4
    static let eliminationStrokes = 7

    private(set) var state: MatchState

    /// Creates a dealt match and its initial lifecycle events. Deliver these
    /// through the same event consumer used for apply and startNextRound.
    static func start(
        players: [PlayerID], dealer: PlayerID? = nil, deck: Deck
    ) throws -> (engine: GameEngine, events: [GameEvent]) {
        let engine = try GameEngine(players: players, dealer: dealer, deck: deck)
        return (engine, [engine.roundStartEvent])
    }

    /// Players are seated in the supplied order, proceeding to the left. The
    /// first seat deals unless a dealer is explicitly supplied. Every match
    /// starts at zero strokes; test scenarios use exact decks and real actions.
    private init(players: [PlayerID], dealer: PlayerID?, deck: Deck) throws {
        guard (2...8).contains(players.count) else { throw GameError.invalidPlayerCount }
        guard Set(players).count == players.count else { throw GameError.duplicatePlayer }
        let dealer = dealer ?? players[0]
        guard players.contains(dealer) else { throw GameError.invalidDealer }
        let playerStates = players.map { PlayerState(id: $0) }
        state = MatchState(
            players: playerStates,
            round: Self.deal(number: 1, dealer: dealer, players: playerStates, deck: deck)
        )
    }

    /// This query also validates submitted actions, so callers and the engine
    /// cannot disagree about whether a card, knock, or response is allowed.
    func legalActions(for player: PlayerID) -> [GameAction] {
        guard state.phase == .playing, state.round.participants.contains(player) else { return [] }
        switch state.round.phase {
        case .playing(let turn):
            guard turn.player == player else { return [] }
            let plays = legalCards(for: player).map(GameAction.playCard)
            switch turn {
            case .mayKnock: return plays + [.knock]
            case .mustPlay: return plays
            }
        case .awaitingResponses(let knock):
            guard knock.expectedResponder == player else { return [] }
            return [.respondToKnock(.hold), .respondToKnock(.pass)]
        case .finished:
            return []
        }
    }

    /// Returns playable cards only when this player currently has a card turn.
    func legalCards(for player: PlayerID) -> [Card] {
        guard state.phase == .playing,
              case .playing(let turn) = state.round.phase,
              turn.player == player,
              let hand = state.round.hands[player] else { return [] }
        guard let lead = state.round.currentTrick.leadSuit else {
            return hand
        }
        let followingSuit = hand.filter { $0.suit == lead }
        return followingSuit.isEmpty ? hand : followingSuit
    }

    @discardableResult
    mutating func apply(_ action: GameAction, by player: PlayerID) throws -> [GameEvent] {
        guard state.players.contains(where: { $0.id == player }) else { throw GameError.unknownPlayer }
        guard state.phase == .playing else { throw GameError.matchFinished }
        guard legalActions(for: player).contains(action) else { throw GameError.illegalAction }

        var events: [GameEvent] = []
        switch action {
        case .playCard(let card): play(card, by: player, events: &events)
        case .knock: knock(by: player, events: &events)
        case .respondToKnock(let response): respond(response, by: player, events: &events)
        }
        return events
    }

    /// Starting a round is a table-level operation, not an action for a bot.
    /// Supplying its deck explicitly keeps shuffling outside rule transitions.
    @discardableResult
    mutating func startNextRound(deck: Deck) throws -> [GameEvent] {
        guard state.phase == .playing else { throw GameError.matchFinished }
        guard case .finished = state.round.phase else { throw GameError.roundNotFinished }
        let dealer = nextPlayer(after: state.round.dealer, among: state.activePlayers)
        state.round = Self.deal(
            number: state.round.number + 1, dealer: dealer, players: state.players, deck: deck
        )
        return [roundStartEvent]
    }

    private var roundStartEvent: GameEvent {
        .roundStarted(number: state.round.number, dealer: state.round.dealer)
    }

    func view(for player: PlayerID) throws -> PlayerView {
        guard state.players.contains(where: { $0.id == player }) else { throw GameError.unknownPlayer }
        let round = state.round
        return PlayerView(
            player: player,
            hand: round.hands[player, default: []],
            players: state.players.map {
                PublicPlayerState(
                    id: $0.id, strokes: $0.strokes, status: $0.status,
                    isParticipating: round.participants.contains($0.id),
                    remainingCardCount: round.hands[$0.id, default: []].count
                )
            },
            matchPhase: state.phase,
            roundNumber: round.number,
            dealer: round.dealer,
            stake: round.stake,
            roundPhase: round.phase,
            currentTrick: round.currentTrick,
            leadSuit: round.currentTrick.leadSuit,
            completedTricks: round.completedTricks,
            knocks: round.knocks,
            legalActions: legalActions(for: player)
        )
    }

    private mutating func play(_ card: Card, by player: PlayerID, events: inout [GameEvent]) {
        let play = PlayedCard(player: player, card: card)
        state.round.hands[player]?.removeAll { $0 == card }
        state.round.currentTrick.append(play)
        events.append(.cardPlayed(play))

        let playedPlayers = state.round.currentTrick.plays.map(\.player)
        let waitingPlayers = state.round.participants.filter { !playedPlayers.contains($0) }
        if !waitingPlayers.isEmpty {
            state.round.phase = .playing(.mayKnock(nextPlayer(after: player, among: waitingPlayers)))
            return
        }

        let trick = state.round.currentTrick
        // Passing never retracts a committed card. The trick winner can therefore
        // be different from the next leader or the round's active winner.
        guard let winner = trick.winningPlay, let lead = trick.leadSuit else {
            preconditionFailure("A completed trick must contain a card.")
        }
        state.round.completedTricks.append(CompletedTrick(trick: trick, winner: winner.player, leadSuit: lead))
        events.append(.trickWon(number: trick.number, winner: winner.player))
        if trick.number == Self.cardsPerPlayer {
            let outcome: RoundOutcome = state.round.participants.contains(winner.player)
                ? .won(winner: winner.player, reason: .finalTrick)
                : .noActiveWinner(trickWinner: winner.player)
            finishRound(outcome, events: &events)
        } else {
            // Earlier tricks determine the next lead, never the round's score.
            state.round.currentTrick = TrickState(number: trick.number + 1)
            // A departed winner keeps the trick, but never receives another turn.
            let leader = state.round.participants.contains(winner.player)
                ? winner.player : nextPlayer(after: winner.player, among: state.round.participants)
            state.round.phase = .playing(.mayKnock(leader))
        }
    }

    private mutating func knock(by player: PlayerID, events: inout [GameEvent]) {
        let previousStake = state.round.stake
        state.round.stake += 1
        state.round.knocks.append(KnockRecord(
            player: player, trickNumber: state.round.currentTrick.number, previousStake: previousStake
        ))
        state.round.phase = .awaitingResponses(PendingKnock(
            player: player, previousStake: previousStake,
            responders: Self.seatsAfter(player, seats: state.players.map(\.id))
                .filter { $0 != player && state.round.participants.contains($0) }
        ))
        events.append(.playerKnocked(player: player, stake: state.round.stake))
    }

    private mutating func respond(_ response: KnockResponse, by player: PlayerID, events: inout [GameEvent]) {
        guard case .awaitingResponses(var pending) = state.round.phase else {
            preconditionFailure("Validated knock responses require a pending knock.")
        }
        state.round.knocks[state.round.knocks.count - 1].responses.append(
            PlayerResponse(player: player, response: response)
        )
        pending.responders.removeFirst()
        switch response {
        case .hold:
            events.append(.playerHeld(player))
        case .pass:
            state.round.participants.removeAll { $0 == player }
            events.append(.playerPassed(player))
            // Passing settles this player's entire round at the old stake. They
            // are removed before final scoring, so they cannot be charged twice.
            addStrokes(pending.previousStake, to: player, events: &events)
        }

        if !pending.responders.isEmpty {
            state.round.phase = .awaitingResponses(pending)
        } else if state.round.participants.count == 1 {
            // Immediate victory takes precedence over every unfinished table card.
            finishRound(.won(winner: pending.player, reason: .opponentsPassed), events: &events)
        } else {
            // Resume the interrupted turn without reopening its knock opportunity.
            // Even the last card of a trick must wait until all responses arrive.
            state.round.phase = .playing(.mustPlay(pending.player))
        }
    }

    private mutating func finishRound(_ outcome: RoundOutcome, events: inout [GameEvent]) {
        state.round.phase = .finished(outcome)
        events.append(.roundEnded(outcome))
        // No active winner means nobody remaining receives scoring immunity.
        // Passed players have already settled and are absent from participants.
        for loser in state.round.participants where loser != outcome.winner {
            addStrokes(state.round.stake, to: loser, events: &events)
        }
        // Resolve the match only after all penalties, never midway through a
        // scoring batch that could eliminate the final surviving player too.
        if state.activePlayers.isEmpty {
            state.phase = .draw
            events.append(.matchDrawn)
        } else if state.activePlayers.count == 1, let winner = state.activePlayers.first {
            state.phase = .finished(winner: winner)
            events.append(.matchWon(winner))
        }
    }

    private mutating func addStrokes(_ amount: Int, to player: PlayerID, events: inout [GameEvent]) {
        guard let index = state.players.firstIndex(where: { $0.id == player }) else {
            preconditionFailure("Only seated players can receive strokes.")
        }
        state.players[index].strokes += amount
        events.append(.strokesAdded(player: player, amount: amount))
        if state.players[index].status == .eliminated {
            events.append(.playerEliminated(player))
        }
    }

    private func nextPlayer(after player: PlayerID, among eligible: [PlayerID]) -> PlayerID {
        Self.seatsAfter(player, seats: state.players.map(\.id)).first { eligible.contains($0) }!
    }

    /// Includes the dealer last, so the same ordering handles both dealing and
    /// wrapping around seats vacated by eliminated players.
    private static func seatsAfter(_ player: PlayerID, seats: [PlayerID]) -> [PlayerID] {
        let index = seats.firstIndex(of: player)!
        return (1...seats.count).map { seats[(index + $0) % seats.count] }
    }

    private static func deal(number: Int, dealer: PlayerID, players: [PlayerState], deck: Deck) -> RoundState {
        let participants = players.filter { $0.status == .active }.map(\.id)
        let dealOrder = seatsAfter(dealer, seats: players.map(\.id)).filter { participants.contains($0) }
        var hands = Dictionary(uniqueKeysWithValues: participants.map { ($0, [Card]()) })
        let dealtCount = participants.count * cardsPerPlayer
        for index in 0..<dealtCount {
            hands[dealOrder[index % dealOrder.count], default: []].append(deck.cards[index])
        }
        return RoundState(
            number: number, dealer: dealer, participants: participants, hands: hands,
            undealtCards: Array(deck.cards.dropFirst(dealtCount)),
            phase: .playing(.mayKnock(dealOrder[0])), currentTrick: TrickState(number: 1)
        )
    }
}
