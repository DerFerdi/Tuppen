import SwiftUI

struct CardView: View {
    let card: Card
    @Environment(AppPreferences.self) private var preferences

    private var suitSymbol: String {
        switch card.suit {
        case .clubs: "♣"
        case .spades: "♠"
        case .hearts: "♥"
        case .diamonds: "♦"
        }
    }

    private var ink: Color {
        card.suit == .hearts || card.suit == .diamonds
            ? Color(red: 0.68, green: 0.12, blue: 0.16) : .black
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(.white)
            .aspectRatio(0.7, contentMode: .fit)
            .overlay {
                VStack(spacing: 4) {
                    Text(preferences.strings.rank(card.rank, abbreviated: true))
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(verbatim: suitSymbol)
                        .font(.system(size: 30, design: .serif))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .minimumScaleFactor(0.7).padding(10).foregroundStyle(ink)
            }
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(.black.opacity(0.16), lineWidth: 1) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(preferences.strings.card(card))
    }
}
