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
        RoundedRectangle(cornerRadius: 8)
            .fill(TableStyle.paper)
            .aspectRatio(0.7, contentMode: .fit)
            .overlay {
                GeometryReader { geometry in
                    let width = geometry.size.width
                    ZStack {
                        Text(verbatim: suitSymbol)
                            .font(.system(size: width * 0.47, design: .serif))
                            .position(x: width * 0.53, y: geometry.size.height * 0.54)
                        VStack {
                            corner(width: width).frame(maxWidth: .infinity, alignment: .leading)
                            Spacer(minLength: 0)
                            corner(width: width).rotationEffect(.degrees(180))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(width * 0.10)
                    }
                    .foregroundStyle(ink)
                }
            }
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.12), lineWidth: 0.75) }
        .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(preferences.strings.card(card))
    }

    private func corner(width: CGFloat) -> some View {
        VStack(spacing: -2) {
            Text(preferences.strings.rank(card.rank, abbreviated: true))
                .font(.system(size: width * 0.25, weight: .semibold, design: .serif))
            Text(verbatim: suitSymbol)
                .font(.system(size: width * 0.16, design: .serif))
        }
    }
}
