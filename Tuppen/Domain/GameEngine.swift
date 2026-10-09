/// The sole authority for rules and scoring. The engine is a value type with no
/// UI dependencies or ambient randomness. Rejected actions leave state unchanged.
struct GameEngine: Sendable {
    static let cardsPerPlayer = 4
    static let eliminationStrokes = 7

    private(set) var state: MatchState

    /// Creates a dealt match and its initial lifecycle events. Deliver these
    /// through the same event consumer used for apply and startNextRound.
    static func start(
        players: [PlayerID], dealer: PlayerID? = nil, deck: Deck, houseRules: HouseRules = .standard
    ) throws -> (engine: GameEngine, events: [GameEvent]) {
        let engine = try GameEngine(players: players, dealer: dealer, deck: deck, houseRules: houseRules)
        return (engine, engine.roundStartEvents)
    }

    /// Players are seated in the supplied order, proceeding to the left. The
    /// first seat deals unless a dealer is explicitly supplied. Every match
    /// starts at zero strokes; test scenarios use exact decks and real actions.
    private init(players: [PlayerID], dealer: PlayerID?, deck: Deck, houseRules: HouseRules) throws {
        guard (2...8).contains(players.count), !houseRules.eightCardRule || players.count <= 5 else { throw GameError.invalidPlayerCount }
        guard Set(players).count == players.count else { throw GameError.duplicatePlayer }
        let dealer = dealer ?? players[0]
        guard players.contains(dealer) else { throw GameError.invalidDealer }
        let playerStates = players.map { PlayerState(id: $0, maximumStrokes: houseRules.maximumStrokes) }
        state = MatchState(
            players: playerStates,
            round: Self.deal(number: 1, dealer: dealer, players: playerStates, deck: deck, houseRules: houseRules),
            houseRules: houseRules
        )
    }

    /// Restores a snapshot only after checking that its current round can be
    /// produced by legal actions. Validation emits no events to session consumers.
    init(restoring snapshot: MatchState) throws {
        do {
            state = try snapshot.roundStartForRestoration()
            self = try replaySavedRound(snapshot)
            if let tiebreak = snapshot.eightCardRule {
                try startEightCardRule(deck: Deck(cards: tiebreak.deck))
                guard (2...4).contains(tiebreak.participants.count),
                      tiebreak.actions.count <= tiebreak.participants.count * 8 else {
                    throw GameError.invalidSavedState
                }
                for action in tiebreak.actions { try apply(action.action, by: action.player) }
            }
            guard state == snapshot else { throw GameError.invalidSavedState }
        } catch {
            throw GameError.invalidSavedState
        }
    }

    /// This query also validates submitted actions, so callers and the engine
    /// cannot disagree about whether a card, knock, or response is allowed.
    func legalActions(for player: PlayerID) -> [GameAction] {
        if state.phase == .eightCardRule {
            return legalCards(for: player).map(GameAction.playCard)
        }
        guard state.phase == .playing, state.round.participants.contains(player) else { return [] }
        switch state.round.phase {
        case .playing(let turn):
            guard turn.player == player else { return [] }
            var actions = legalCards(for: player).map(GameAction.playCard)
            if case .mayKnock = turn, state.round.poorParticipants.isEmpty {
                if !state.houseRules.consecutiveKnockRestriction || state.lastOrdinaryKnocker != player {
                    actions.append(.knock)
                }
                if canClaimFourPictures(player) { actions.append(.claimFourPictures) }
            }
            return actions
        case .awaitingResponses(let pending):
            guard pending.expectedResponder == player else { return [] }
            return [.respondToKnock(.hold), .respondToKnock(.pass)]
        case .awaitingPovertyResponses(let pending):
            guard pending.expectedResponder == player else { return [] }
            return [.respondToPoverty(.hold), .respondToPoverty(.pass)]
        case .awaitingFourPicturesChallenges(let pending):
            guard pending.expectedResponder == player else { return [] }
            return [.respondToFourPictures(.challenge), .respondToFourPictures(.decline)]
        case .finished:
            return []
        }
    }

    /// The authoritative actor includes optional-rule decisions and tiebreak
    /// card turns; callers never need to reconstruct response ordering.
    var expectedActor: PlayerID? {
        if state.phase == .eightCardRule { return state.eightCardRule?.currentPlayer }
        guard state.phase == .playing else { return nil }
        switch state.round.phase {
        case .playing(let turn): return turn.player
        case .awaitingResponses(let pending): return pending.expectedResponder
        case .awaitingPovertyResponses(let pending): return pending.expectedResponder
        case .awaitingFourPicturesChallenges(let pending): return pending.expectedResponder
        case .finished: return nil
        }
    }

    /// Returns playable cards only when this player currently has a card turn.
    func legalCards(for player: PlayerID) -> [Card] {
        if state.phase == .eightCardRule, let tiebreak = state.eightCardRule,
           tiebreak.currentPlayer == player {
            return Self.followingCards(tiebreak.hands[player, default: []], lead: tiebreak.currentTrick.leadSuit)
        }
        guard state.phase == .playing,
              case .playing(let turn) = state.round.phase,
              turn.player == player,
              let hand = state.round.hands[player] else { return [] }
        return Self.followingCards(hand, lead: state.round.currentTrick.leadSuit)
    }

    private static func followingCards(_ hand: [Card], lead: Suit?) -> [Card] {
        guard let lead else { return hand }
        let followingSuit = hand.filter { $0.suit == lead }
        return followingSuit.isEmpty ? hand : followingSuit
    }

    @discardableResult
    mutating func apply(_ action: GameAction, by player: PlayerID) throws -> [GameEvent] {
        guard state.players.contains(where: { $0.id == player }) else { throw GameError.unknownPlayer }
        guard state.phase.isActive else { throw GameError.matchFinished }
        guard legalActions(for: player).contains(action) else { throw GameError.illegalAction }

        var events: [GameEvent] = []
        if state.phase == .eightCardRule, case .playCard(let card) = action {
            playEightCard(card, by: player, events: &events)
            state.eightCardRule?.actions.append(RecordedAction(player: player, action: action))
            return events
        }
        switch action {
        case .playCard(let card): play(card, by: player, events: &events)
        case .knock: knock(by: player, events: &events)
        case .respondToKnock(let response): respond(response, by: player, events: &events)
        case .respondToPoverty(let response): respondToPoverty(response, by: player, events: &events)
        case .claimFourPictures: claimFourPictures(by: player, events: &events)
        case .respondToFourPictures(let response): respondToFourPictures(response, by: player, events: &events)
        }
        state.round.history?.actions.append(RecordedAction(player: player, action: action))
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
            number: state.round.number + 1, dealer: dealer, players: state.players, deck: deck,
            houseRules: state.houseRules, lastOrdinaryKnocker: state.lastOrdinaryKnocker
        )
        return roundStartEvents
    }

    private var roundStartEvents: [GameEvent] {
        var events: [GameEvent] = [.roundStarted(number: state.round.number, dealer: state.round.dealer)]
        if !state.round.poorParticipants.isEmpty {
            events.append(.povertyStarted(participants: state.round.poorParticipants))
        }
        return events
    }

    func view(for player: PlayerID) throws -> PlayerView {
        guard state.players.contains(where: { $0.id == player }) else { throw GameError.unknownPlayer }
        let round = state.round
        let tiebreak = state.eightCardRule
        let hands = tiebreak?.hands ?? round.hands
        let participants = tiebreak?.participants ?? round.participants
        let trick = tiebreak?.currentTrick ?? round.currentTrick
        let phase: RoundPhase
        if let tiebreak, let actor = tiebreak.currentPlayer {
            phase = .playing(.mustPlay(actor))
        } else if tiebreak != nil, case .finished(let winner) = state.phase {
            phase = .finished(.won(winner: winner, reason: .finalTrick))
        } else {
            phase = round.phase
        }
        return PlayerView(
            player: player, hand: hands[player, default: []],
            players: state.players.map {
                PublicPlayerState(
                    id: $0.id, strokes: $0.strokes, status: $0.status,
                    isParticipating: participants.contains($0.id),
                    remainingCardCount: hands[$0.id, default: []].count
                )
            },
            matchPhase: state.phase, roundNumber: round.number,
            dealer: tiebreak?.dealer ?? round.dealer, stake: tiebreak == nil ? round.stake : 1,
            roundPhase: phase, currentTrick: trick, leadSuit: trick.leadSuit,
            completedTricks: tiebreak?.completedTricks ?? round.completedTricks,
            knocks: tiebreak == nil ? round.knocks : [], legalActions: legalActions(for: player),
            houseRules: state.houseRules, lastOrdinaryKnocker: state.lastOrdinaryKnocker,
            poorParticipants: tiebreak == nil ? round.poorParticipants : [],
            povertyResponses: tiebreak == nil ? round.povertyResponses : [],
            revealedHands: tiebreak == nil ? round.revealedHands : [], isEightCardRule: tiebreak != nil
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

        completeTrick(events: &events)
    }

    private mutating func completeTrick(events: inout [GameEvent]) {
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
        if state.houseRules.consecutiveKnockRestriction { state.lastOrdinaryKnocker = player }
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
        let survivorsBeforeScoring = state.activePlayers
        // No active winner means nobody remaining receives scoring immunity.
        // Passed players have already settled and are absent from participants.
        for loser in state.round.participants where loser != outcome.winner {
            addStrokes(state.round.stake, to: loser, events: &events)
        }
        // Resolve the match only after all penalties, never midway through a
        // scoring batch that could eliminate the final surviving player too.
        if state.activePlayers.isEmpty {
            if state.houseRules.eightCardRule {
                state.phase = .awaitingEightCardDeal(participants: survivorsBeforeScoring)
            } else {
                state.phase = .draw
                events.append(.matchDrawn)
            }
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

    static func deal(
        number: Int, dealer: PlayerID, players: [PlayerState], deck: Deck,
        houseRules: HouseRules = .standard, lastOrdinaryKnocker: PlayerID? = nil
    ) -> RoundState {
        let participants = players.filter { $0.status == .active }.map(\.id)
        let dealOrder = seatsAfter(dealer, seats: players.map(\.id)).filter { participants.contains($0) }
        var hands = Dictionary(uniqueKeysWithValues: participants.map { ($0, [Card]()) })
        let dealtCount = participants.count * cardsPerPlayer
        for index in 0..<dealtCount {
            hands[dealOrder[index % dealOrder.count], default: []].append(deck.cards[index])
        }
        var round = RoundState(
            number: number, dealer: dealer, participants: participants, hands: hands,
            undealtCards: Array(deck.cards.dropFirst(dealtCount)),
            phase: .playing(.mayKnock(dealOrder[0])), currentTrick: TrickState(number: 1)
        )
        if houseRules != .standard {
            round.history = RoundHistory(initialPlayers: players, deck: deck.cards, lastOrdinaryKnocker: lastOrdinaryKnocker)
        }
        if houseRules.poverty {
            round.poorParticipants = players.filter {
                $0.status == .active && $0.strokes == houseRules.maximumStrokes.rawValue - 1
            }.map(\.id)
            if !round.poorParticipants.isEmpty {
                round.stake = 2
                let responders = dealOrder.filter { !round.poorParticipants.contains($0) }
                if !responders.isEmpty { round.phase = .awaitingPovertyResponses(PendingPoverty(responders: responders)) }
            }
        }
        return round
    }
}

private extension GameEngine {
    func canClaimFourPictures(_ player: PlayerID) -> Bool {
        guard state.houseRules.fourPictures, state.round.undealtCards.count >= 4,
              let hand = state.round.hands[player], hand.count == 4 else { return false }
        return state.houseRules.fourPicturesBluffing || hand.isFourPictures
    }

    mutating func respondToPoverty(_ response: KnockResponse, by player: PlayerID, events: inout [GameEvent]) {
        guard case .awaitingPovertyResponses(var pending) = state.round.phase else { return }
        pending.responders.removeFirst()
        state.round.povertyResponses.append(PlayerResponse(player: player, response: response))
        switch response {
        case .hold: events.append(.playerHeld(player))
        case .pass:
            state.round.participants.removeAll { $0 == player }
            events.append(.playerPassed(player))
            addStrokes(1, to: player, events: &events)
        }
        if !pending.responders.isEmpty {
            state.round.phase = .awaitingPovertyResponses(pending)
        } else if state.round.participants.count == 1 {
            finishRound(.won(winner: state.round.participants[0], reason: .opponentsPassed), events: &events)
        } else {
            let leader = nextPlayer(after: state.round.dealer, among: state.round.participants)
            state.round.phase = .playing(.mayKnock(leader))
        }
    }

    mutating func claimFourPictures(by player: PlayerID, events: inout [GameEvent]) {
        events.append(.fourPicturesClaimed(player))
        if state.houseRules.fourPicturesBluffing {
            let responders = Self.seatsAfter(player, seats: state.players.map(\.id))
                .filter { $0 != player && state.round.participants.contains($0) }
            state.round.phase = .awaitingFourPicturesChallenges(PendingFourPictures(claimant: player, responders: responders))
        } else {
            exchangeFourPictures(for: player, events: &events)
        }
    }

    mutating func respondToFourPictures(
        _ response: FourPicturesResponse, by player: PlayerID, events: inout [GameEvent]
    ) {
        guard case .awaitingFourPicturesChallenges(var pending) = state.round.phase else { return }
        switch response {
        case .decline:
            events.append(.fourPicturesDeclined(player))
            pending.responders.removeFirst()
            if pending.responders.isEmpty {
                // Acceptance does not verify or publish a hidden bluff. Only the
                // completed exchange becomes public; bookkeeping may inspect its owner's hand.
                exchangeFourPictures(for: pending.claimant, events: &events)
            } else {
                state.round.phase = .awaitingFourPicturesChallenges(pending)
            }
        case .challenge:
            events.append(.fourPicturesChallenged(claimant: pending.claimant, challenger: player))
            let hand = state.round.hands[pending.claimant, default: []]
            let revelation = RevealedHand(player: pending.claimant, cards: hand)
            state.round.revealedHands.append(revelation)
            events.append(.fourPicturesRevealed(revelation))
            let truthful = hand.isFourPictures
            if !truthful { events.append(.fourPicturesBluffExposed(pending.claimant)) }
            let penalized = truthful ? player : pending.claimant
            addStrokes(1, to: penalized, events: &events)
            if !state.activePlayers.contains(penalized) {
                state.round.participants.removeAll { $0 == penalized }
            }
            // A sole participant wins before any replacement is drawn. Passed
            // match survivors do not keep this interrupted round open.
            if state.round.participants.count == 1 {
                finishRound(.won(winner: state.round.participants[0], reason: .opponentsEliminated), events: &events)
            } else if truthful {
                exchangeFourPictures(for: pending.claimant, events: &events)
            } else if state.round.participants.contains(pending.claimant) {
                state.round.phase = .playing(.mayKnock(pending.claimant))
            } else {
                let waiting = state.round.participants.filter { candidate in
                    !state.round.currentTrick.plays.contains { $0.player == candidate }
                }
                // Claims are confined to the first card turn, so a departed
                // claimant can leave a complete first trick behind.
                if waiting.isEmpty {
                    completeTrick(events: &events)
                } else {
                    state.round.phase = .playing(.mayKnock(nextPlayer(after: pending.claimant, among: waiting)))
                }
            }
        }
    }

    mutating func exchangeFourPictures(for player: PlayerID, events: inout [GameEvent]) {
        state.round.removedHands.append(state.round.hands[player, default: []])
        state.round.hands[player] = Array(state.round.undealtCards.prefix(4))
        state.round.undealtCards.removeFirst(4)
        state.round.phase = .playing(.mayKnock(player))
        events.append(.fourPicturesExchanged(player))
    }
}

extension GameEngine {
    /// The application supplies a fresh shuffled deck and saves its advanced RNG
    /// in the same transaction. No provisional Draw or extra round is emitted.
    @discardableResult
    mutating func startEightCardRule(deck: Deck) throws -> [GameEvent] {
        guard case .awaitingEightCardDeal(let participants) = state.phase,
              (2...4).contains(participants.count) else { throw GameError.illegalAction }
        let dealer = nextPlayer(after: state.round.dealer, among: participants)
        let order = Self.seatsAfter(dealer, seats: state.players.map(\.id)).filter { participants.contains($0) }
        var hands = Dictionary(uniqueKeysWithValues: participants.map { ($0, [Card]()) })
        let dealt = participants.count * 8
        for index in 0..<dealt {
            hands[order[index % order.count], default: []].append(deck.cards[index])
        }
        state.eightCardRule = EightCardState(
            participants: participants, dealer: dealer, hands: hands,
            undealtCards: Array(deck.cards.dropFirst(dealt)), currentTrick: TrickState(number: 1),
            currentPlayer: order[0], deck: deck.cards
        )
        state.phase = .eightCardRule
        return [.eightCardRuleStarted(participants: participants, dealer: dealer)]
    }

    private mutating func playEightCard(_ card: Card, by player: PlayerID, events: inout [GameEvent]) {
        guard var tiebreak = state.eightCardRule else { return }
        let play = PlayedCard(player: player, card: card)
        tiebreak.hands[player]?.removeAll { $0 == card }
        tiebreak.currentTrick.append(play)
        events.append(.cardPlayed(play))
        let waiting = tiebreak.participants.filter { candidate in
            !tiebreak.currentTrick.plays.contains { $0.player == candidate }
        }
        if !waiting.isEmpty {
            tiebreak.currentPlayer = nextPlayer(after: player, among: waiting)
        } else if let winner = tiebreak.currentTrick.winningPlay, let lead = tiebreak.currentTrick.leadSuit {
            let number = tiebreak.currentTrick.number
            tiebreak.completedTricks.append(CompletedTrick(trick: tiebreak.currentTrick, winner: winner.player, leadSuit: lead))
            events.append(.trickWon(number: number, winner: winner.player))
            if number == 8 {
                tiebreak.currentPlayer = nil
                state.phase = .finished(winner: winner.player)
                events.append(.eightCardRuleEnded(winner: winner.player, participants: tiebreak.participants))
                events.append(.matchWon(winner.player))
            } else {
                tiebreak.currentTrick = TrickState(number: number + 1)
                tiebreak.currentPlayer = winner.player
            }
        }
        state.eightCardRule = tiebreak
    }
}
