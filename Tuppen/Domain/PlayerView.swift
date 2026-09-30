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
}
