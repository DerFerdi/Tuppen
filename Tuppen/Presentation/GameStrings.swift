import Foundation

/// Select the catalog's compiled language bundle explicitly for strings built
/// outside Text. SwiftUI receives the same locale for native formatting.
struct GameStrings {
    let locale: Locale

    func text(_ value: String.LocalizationValue) -> String {
        let code = locale.language.languageCode?.identifier ?? "en"
        let bundle = Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
        return String(localized: value, bundle: bundle, locale: locale)
    }

    func player(_ id: PlayerID, in view: PlayerView) -> String {
        if id == view.player { return text("You") }
        let opponents = view.players.filter { $0.id != view.player }
        let number = (opponents.firstIndex { $0.id == id } ?? 0) + 1
        return text("Opponent \(number)")
    }

    func rank(_ rank: Rank, abbreviated: Bool = false) -> String {
        switch rank {
        case .jack: text(abbreviated ? "J" : "Jack")
        case .queen: text(abbreviated ? "Q" : "Queen")
        case .king: text(abbreviated ? "K" : "King")
        case .ace: text(abbreviated ? "A" : "Ace")
        case .seven: text(abbreviated ? "7" : "Seven")
        case .eight: text(abbreviated ? "8" : "Eight")
        case .nine: text(abbreviated ? "9" : "Nine")
        case .ten: text(abbreviated ? "10" : "Ten")
        }
    }

    func suit(_ suit: Suit) -> String {
        switch suit {
        case .clubs: text("Clubs")
        case .spades: text("Spades")
        case .hearts: text("Hearts")
        case .diamonds: text("Diamonds")
        }
    }

    func card(_ card: Card) -> String {
        text("\(rank(card.rank)) of \(suit(card.suit))")
    }

    func roundResult(_ outcome: RoundOutcome, in view: PlayerView) -> String {
        switch outcome {
        case .won(let winner, _):
            winner == view.player ? text("You win the round.") : text("\(player(winner, in: view)) wins the round.")
        case .noActiveWinner: text("No active winner.")
        }
    }

    func failure(_ failure: AppFailure) -> String {
        switch failure {
        case .restore: text("Your saved game could not be opened. Try again, or start a new game to replace it.")
        case .save: text("The change could not be saved. Your last saved position is safe. Please try again.")
        case .reset: text("Statistics could not be reset. Your previous statistics are unchanged.")
        }
    }
}
