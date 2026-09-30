/// Stable identity independent of seat position, display name, and localization.
struct PlayerID: Hashable, Sendable {
    let rawValue: Int
}

enum PlayerStatus: Equatable, Sendable {
    case active
    case eliminated
}

struct PlayerState: Equatable, Sendable {
    let id: PlayerID
    var strokes = 0

    var status: PlayerStatus {
        strokes >= GameEngine.eliminationStrokes ? .eliminated : .active
    }
}

struct PlayedCard: Equatable, Sendable {
    let player: PlayerID
    let card: Card
}

struct TrickState: Equatable, Sendable {
    let number: Int
    /// Committed cards remain eligible even if their owners pass or are eliminated.
    private(set) var plays: [PlayedCard]
    /// Established once by the first card, independent of later participation.
    private(set) var leadSuit: Suit?

    init(number: Int, plays: [PlayedCard] = []) {
        self.number = number
        self.plays = plays
        leadSuit = plays.first?.card.suit
    }

    mutating func append(_ play: PlayedCard) {
        if plays.isEmpty { leadSuit = play.card.suit }
        plays.append(play)
    }

    var winningPlay: PlayedCard? {
        guard let leadSuit else { return nil }
        return plays.filter { $0.card.suit == leadSuit }
            .max { $0.card.rank < $1.card.rank }
    }
}

struct CompletedTrick: Equatable, Sendable {
    let trick: TrickState
    let winner: PlayerID
    /// The original lead is retained alongside the completed public trick.
    let leadSuit: Suit
}

/// A knock consumes this turn's opportunity to raise, even after everyone holds.
enum TurnState: Equatable, Sendable {
    case mayKnock(PlayerID)
    case mustPlay(PlayerID)

    var player: PlayerID {
        switch self {
        case .mayKnock(let player), .mustPlay(let player): player
        }
    }
}

enum KnockResponse: Equatable, Sendable {
    case hold
    case pass
}

struct PlayerResponse: Equatable, Sendable {
    let player: PlayerID
    let response: KnockResponse
}

struct KnockRecord: Equatable, Sendable {
    let player: PlayerID
    let trickNumber: Int
    let previousStake: Int
    var responses: [PlayerResponse] = []

    var raisedStake: Int { previousStake + 1 }
}

struct PendingKnock: Equatable, Sendable {
    let player: PlayerID
    let previousStake: Int
    /// Outstanding responses in table order after the knocker. Earlier decisions
    /// are public before the next player acts; only the head may respond.
    var responders: [PlayerID]

    var expectedResponder: PlayerID? { responders.first }
}

enum RoundWinReason: Equatable, Sendable {
    case finalTrick
    case opponentsPassed
}

enum RoundOutcome: Equatable, Sendable {
    case won(winner: PlayerID, reason: RoundWinReason)
    /// The winning card belongs to a departed player; every remaining player loses.
    case noActiveWinner(trickWinner: PlayerID)

    var winner: PlayerID? {
        switch self {
        case .won(let winner, _): winner
        case .noActiveWinner: nil
        }
    }
}

/// Card turns and response windows are mutually exclusive. A finished round has
/// no current player and cannot accept further card plays or knock responses.
enum RoundPhase: Equatable, Sendable {
    case playing(TurnState)
    case awaitingResponses(PendingKnock)
    case finished(RoundOutcome)

    /// During a response window, the knocking player retains the interrupted turn.
    var currentPlayer: PlayerID? {
        switch self {
        case .playing(let turn): turn.player
        case .awaitingResponses(let knock): knock.player
        case .finished: nil
        }
    }
}

struct RoundState: Equatable, Sendable {
    let number: Int
    let dealer: PlayerID
    var participants: [PlayerID]
    var hands: [PlayerID: [Card]]
    let undealtCards: [Card]
    var stake = 1
    var phase: RoundPhase
    var currentTrick: TrickState
    var completedTricks: [CompletedTrick] = []
    var knocks: [KnockRecord] = []
}

enum MatchPhase: Equatable, Sendable {
    case playing
    case finished(winner: PlayerID)
    /// Final-trick scoring eliminated all surviving match players together.
    case draw
}

/// Authoritative state contains secrets. Pass PlayerView, never MatchState, to
/// decision-making code for an individual player. Snapshots are value copies;
/// only GameEngine can replace its own authoritative state.
struct MatchState: Equatable, Sendable {
    /// Seat order is fixed for the match, including seats of eliminated players.
    var players: [PlayerState]
    var round: RoundState
    var phase: MatchPhase = .playing

    var activePlayers: [PlayerID] {
        players.filter { $0.status == .active }.map(\.id)
    }
}
