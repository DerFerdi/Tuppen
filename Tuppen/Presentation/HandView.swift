import SwiftUI

struct HandView: View {
    let cards: [Card]
    let namespace: Namespace.ID
    var eightCardRule = false
    @Environment(AppModel.self) private var model
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let layout = HandLayout(width: geometry.size.width, height: geometry.size.height, eightCardRule: eightCardRule)
            VStack(spacing: 8) {
                ForEach(0..<layout.rows, id: \.self) { row in
                    let rowCards = Array(cards.dropFirst(row * 4).prefix(4))
                    HStack(spacing: layout.spacing) {
                        ForEach(Array(rowCards.enumerated()), id: \.element) { index, card in
                            cardButton(card, index: index, count: rowCards.count, width: layout.cardWidth)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(preferences.strings.text("Your hand"))
        }
        .animation(.easeInOut(duration: TablePacing.motionDuration(reduceMotion: reduceMotion)), value: cards)
    }

    private func cardButton(_ card: Card, index: Int, count: Int, width: CGFloat) -> some View {
        let legal = model.canSubmit(.playCard(card))
        let position = Double(index) - Double(count - 1) / 2
        return Button { Task { await model.submit(.playCard(card)) } } label: {
            CardView(card: card)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(TableStyle.accent.opacity(legal ? 0.8 : 0), lineWidth: 1.5)
                }
                .opacity(legal ? 1 : 0.80)
                .modifier(HandCardMotion(card: card, namespace: namespace, reduceMotion: reduceMotion))
        }
        .buttonStyle(CardPressStyle())
        .disabled(!legal)
        .frame(width: width)
        .rotationEffect(.degrees(reduceMotion ? 0 : position * 3))
        .offset(y: reduceMotion ? 0 : abs(position) * 3 - (legal ? 4 : 0))
        .accessibilityLabel(preferences.strings.card(card))
        .accessibilityValue(model.view.map {
            preferences.strings.cardAvailability(card, in: $0, busy: model.isBusy)
        } ?? preferences.strings.text("Currently unavailable"))
        .accessibilityHint(legal ? preferences.strings.text("Play this card") : "")
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
    }
}

private struct HandCardMotion: ViewModifier {
    let card: Card
    let namespace: Namespace.ID
    let reduceMotion: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if reduceMotion { content }
        else { content.matchedGeometryEffect(id: card, in: namespace) }
    }
}
