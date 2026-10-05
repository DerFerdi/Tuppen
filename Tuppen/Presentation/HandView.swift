import SwiftUI

struct HandView: View {
    let cards: [Card]
    let namespace: Namespace.ID
    @Environment(AppModel.self) private var model
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let width = min(108, (geometry.size.height - 14) * 0.7)
            let spacing = cards.count > 1
                ? min(12, (geometry.size.width - 20 - width * CGFloat(cards.count)) / CGFloat(cards.count - 1)) : 0
            HStack(spacing: spacing) {
                ForEach(Array(cards.enumerated()), id: \.element) { index, card in
                    let legal = model.canSubmit(.playCard(card))
                    let position = Double(index) - Double(cards.count - 1) / 2
                    Button { Task { await model.submit(.playCard(card)) } } label: {
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
            .frame(width: geometry.size.width, height: geometry.size.height)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(preferences.strings.text("Your hand"))
        }
        .animation(.easeInOut(duration: TablePacing.motionDuration(reduceMotion: reduceMotion)), value: cards)
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
