struct PendingPoverty: Equatable, Codable, Sendable {
    var responders: [PlayerID]
    var expectedResponder: PlayerID? { responders.first }
}

enum FourPicturesResponse: Equatable, Codable, Sendable {
    case challenge
    case decline
}

/// The original hand stays in authoritative hand storage until resolution. This
/// public queue intentionally contains neither cards nor the truth of the claim.
struct PendingFourPictures: Equatable, Codable, Sendable {
    let claimant: PlayerID
    var responders: [PlayerID]
    var expectedResponder: PlayerID? { responders.first }
}

struct RevealedHand: Equatable, Codable, Sendable {
    let player: PlayerID
    let cards: [Card]
}

struct RecordedAction: Equatable, Codable, Sendable {
    let player: PlayerID
    let action: GameAction
}

/// Private current-round replay material. Exchanges cannot be reconstructed
/// from public plays alone; neither this deck nor this journal crosses PlayerView.
struct RoundHistory: Equatable, Codable, Sendable {
    let initialPlayers: [PlayerState]
    let deck: [Card]
    let lastOrdinaryKnocker: PlayerID?
    var actions: [RecordedAction] = []
}

/// Separate from the completed scored round: retained strokes no longer decide
/// participation, and finishing this state never emits a normal round outcome.
struct EightCardState: Equatable, Codable, Sendable {
    let participants: [PlayerID]
    let dealer: PlayerID
    var hands: [PlayerID: [Card]]
    let undealtCards: [Card]
    var currentTrick: TrickState
    var completedTricks: [CompletedTrick] = []
    var currentPlayer: PlayerID?
    let deck: [Card]
    var actions: [RecordedAction] = []
}
