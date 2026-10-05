import Foundation

/// Beginner essentials only. Detailed edge cases remain in the rules reference.
enum TutorialStep: CaseIterable, Identifiable {
    case cards, ranks, followingSuit, finalTrick, strokes, knock, hold, pass

    var id: Self { self }

    var title: String.LocalizationValue {
        switch self {
        case .cards: "Four cards each"
        case .ranks: "Ten is strongest"
        case .followingSuit: "Follow the led suit"
        case .finalTrick: "The fourth trick decides"
        case .strokes: "Stay below seven strokes"
        case .knock: "Knock"
        case .hold: "Hold"
        case .pass: "Pass"
        }
    }

    var explanation: String.LocalizationValue {
        switch self {
        case .cards:
            "You play against two opponents. Each active player receives four cards. The suits are Clubs, Spades, Hearts, and Diamonds."
        case .ranks:
            "From weakest to strongest: Jack, Queen, King, Ace, Seven, Eight, Nine, Ten. There is no trump suit."
        case .followingSuit:
            "Each player plays one card into a trick. The first card sets the suit. If you have that suit, you must follow it; otherwise, play any card. The highest card of the led suit wins."
        case .finalTrick:
            "A normal round has four tricks. Only the fourth trick wins the round. Winning an earlier trick lets you lead the next one, but does not win the round."
        case .strokes:
            "The stake starts at one. Losing a round normally gives one stroke. At seven or more strokes, you are eliminated. The last player remaining wins the match."
        case .knock:
            "Only the player whose turn it is may Knock, before playing a card. Each Knock raises the stake by one. After the responses, play your card; you cannot Knock again on that turn."
        case .hold:
            "After a Knock, Hold accepts the higher stake and keeps you in the round. If the stake rises from one to two and you later lose, you receive two strokes."
        case .pass:
            "Pass leaves the round and gives you the previous stake in strokes. If the stake rises from one to two, passing gives you one stroke. If everyone else passes, the knocker wins the round immediately."
        }
    }
}
