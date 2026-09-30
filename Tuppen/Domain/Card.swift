/// Suits have no relative strength: Tuppen has no trump suit.
enum Suit: String, CaseIterable, Sendable {
    case clubs, spades, hearts, diamonds
}

/// Raw values encode Tuppen strength, not the values used in poker or bridge.
enum Rank: Int, CaseIterable, Comparable, Sendable {
    case jack, queen, king, ace, seven, eight, nine, ten

    static func < (lhs: Rank, rhs: Rank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct Card: Hashable, Sendable {
    let suit: Suit
    let rank: Rank
}

/// A complete deck in deal order. Keeping construction validated makes exact deals
/// available to tests without allowing duplicate or missing cards into a match.
struct Deck: Equatable, Sendable {
    let cards: [Card]

    static let ordered = Deck()

    private init(shuffledCards: [Card]) {
        cards = shuffledCards
    }

    private init() {
        cards = Suit.allCases.flatMap { suit in
            Rank.allCases.map { Card(suit: suit, rank: $0) }
        }
    }

    init(cards: [Card]) throws {
        guard cards.count == 32, Set(cards) == Set(Self.ordered.cards) else {
            throw GameError.invalidDeck
        }
        self.cards = cards
    }

    /// All randomness enters at the deal boundary. Callers own the generator;
    /// rules and legal-action queries never consume random values.
    static func shuffled<R: RandomNumberGenerator>(using generator: inout R) -> Deck {
        // Shuffling preserves the validated deck's membership.
        Deck(shuffledCards: ordered.cards.shuffled(using: &generator))
    }
}
