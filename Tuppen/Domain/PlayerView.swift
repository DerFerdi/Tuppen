struct PublicPlayerState: Equatable, Sendable {
    let id: PlayerID
    let strokes: Int
    let status: PlayerStatus
    let isParticipating: Bool
    let remainingCardCount: Int
}

/// An allowlist of what one seat may know. This type deliberately has no engine
/// reference, opponent-hand dictionary, or undealt-card storage. Equal public
/// histories and equal own hands must produce equal views, regardless of secrets.
struct PlayerView: Equatable, Sendable {
    let player: PlayerID
    let hand: [Card]
    let players: [PublicPlayerState]
    let matchPhase: MatchPhase
    let roundNumber: Int
    let dealer: PlayerID
    let stake: Int
    let roundPhase: RoundPhase
    let currentTrick: TrickState
    let leadSuit: Suit?
    let completedTricks: [CompletedTrick]
    let knocks: [KnockRecord]
    let legalActions: [GameAction]
    let houseRules: HouseRules
    let lastOrdinaryKnocker: PlayerID?
    let poorParticipants: [PlayerID]
    let povertyResponses: [PlayerResponse]
    let revealedHands: [RevealedHand]
    let isEightCardRule: Bool

    init(
        player: PlayerID, hand: [Card], players: [PublicPlayerState], matchPhase: MatchPhase,
        roundNumber: Int, dealer: PlayerID, stake: Int, roundPhase: RoundPhase,
        currentTrick: TrickState, leadSuit: Suit?, completedTricks: [CompletedTrick],
        knocks: [KnockRecord], legalActions: [GameAction], houseRules: HouseRules = .standard,
        lastOrdinaryKnocker: PlayerID? = nil, poorParticipants: [PlayerID] = [],
        povertyResponses: [PlayerResponse] = [], revealedHands: [RevealedHand] = [], isEightCardRule: Bool = false
    ) {
        self.player = player
        self.hand = hand
        self.players = players
        self.matchPhase = matchPhase
        self.roundNumber = roundNumber
        self.dealer = dealer
        self.stake = stake
        self.roundPhase = roundPhase
        self.currentTrick = currentTrick
        self.leadSuit = leadSuit
        self.completedTricks = completedTricks
        self.knocks = knocks
        self.legalActions = legalActions
        self.houseRules = houseRules
        self.lastOrdinaryKnocker = lastOrdinaryKnocker
        self.poorParticipants = poorParticipants
        self.povertyResponses = povertyResponses
        self.revealedHands = revealedHands
        self.isEightCardRule = isEightCardRule
    }
}
