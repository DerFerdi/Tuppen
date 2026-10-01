/// Actions contain intent only; callers cannot supply scoring or state changes.
enum GameAction: Equatable, Sendable {
    case playCard(Card)
    case knock
    case respondToKnock(KnockResponse)
}

/// Public facts produced in resolution order. Events never contain hidden hands
/// or undealt cards; the authoritative state is already updated when returned.
enum GameEvent: Equatable, Sendable {
    case roundStarted(number: Int, dealer: PlayerID)
    case cardPlayed(PlayedCard)
    case playerKnocked(player: PlayerID, stake: Int)
    case playerHeld(PlayerID)
    case playerPassed(PlayerID)
    case trickWon(number: Int, winner: PlayerID)
    case roundEnded(RoundOutcome)
    case strokesAdded(player: PlayerID, amount: Int)
    case playerEliminated(PlayerID)
    case matchWon(PlayerID)
    case matchDrawn
}

enum GameError: Error, Equatable {
    case invalidDeck
    case invalidPlayerCount
    case duplicatePlayer
    case unknownPlayer
    case invalidDealer
    case illegalAction
    case roundNotFinished
    case matchFinished
    case invalidSavedState
}
