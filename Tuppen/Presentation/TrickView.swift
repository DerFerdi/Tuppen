import SwiftUI

struct TrickView: View {
    let table: TablePresentation
    let namespace: Namespace.ID
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 4) {
            // The engine supplies the original led suit even after its player
            // leaves. Reserve this line so revealing it cannot move the cards.
            Text(table.trick.leadSuit.map { preferences.strings.text("Led suit: \(preferences.strings.suit($0))") } ?? "")
                .font(.caption2).foregroundStyle(.secondary)
                .dynamicTypeSize(...DynamicTypeSize.large)
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(height: 16)
                .accessibilityHidden(true)
            trickCards
        }
        .animation(.easeInOut(duration: TablePacing.motionDuration(reduceMotion: reduceMotion)), value: table.trick)
        .animation(.easeInOut(duration: TablePacing.motionDuration(reduceMotion: reduceMotion)), value: table.highlightedWinner)
        .animation(.easeInOut(duration: TablePacing.motionDuration(reduceMotion: reduceMotion)), value: table.collecting)
        // Spatial card positions do not define reading order. Speak committed
        // cards in play order, including a passed player's public card.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(preferences.strings.text("Current trick"))
        .accessibilityValue(accessibilitySummary)
    }

    private var trickCards: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let cardWidth = table.seating.cardWidth(in: size)
            ZStack {
                Ellipse()
                    .fill(.primary.opacity(0.025))
                    .frame(width: size.width * 0.91, height: size.height * 0.85)
                    .position(x: size.width / 2, y: size.height / 2)
                    .accessibilityHidden(true)
                // Fixed seat positions also retain cards committed by a player
                // who has passed. Participation never filters the public trick.
                ForEach(table.trick.plays, id: \.player) { play in
                    if let position = table.seating.position(for: play.player, in: size) {
                        playedCard(play, width: cardWidth)
                            .position(position)
                            .offset(collectionOffset(in: size))
                            .opacity(table.collecting ? 0 : 1)
                    }
                }
            }
        }
    }

    @ViewBuilder private func playedCard(_ play: PlayedCard, width: CGFloat) -> some View {
        let highlighted = table.highlightedWinner == play.player
        Group {
            if !reduceMotion, play.player == table.view.player {
                CardView(card: play.card)
                    .matchedGeometryEffect(id: play.card, in: namespace)
            } else {
                CardView(card: play.card)
            }
        }
        .frame(width: width)
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(TableStyle.accent, lineWidth: highlighted ? 2 : 0)
                .padding(-3)
        }
        .scaleEffect(highlighted && !reduceMotion ? 1.055 : 1)
        .rotationEffect(.degrees(reduceMotion ? 0 : table.seating.angle(for: play.player)))
        .zIndex(highlighted ? 1 : 0)
        .transition(reduceMotion ? .opacity : .offset(x: 0, y: play.player == table.view.player ? 45 : -35).combined(with: .opacity))
        .accessibilityLabel(preferences.strings.text("\(preferences.strings.player(play.player, in: table.view)): \(preferences.strings.card(play.card))"))
        .accessibilityValue(highlighted ? preferences.strings.text("Trick winner") : "")
    }

    private func collectionOffset(in size: CGSize) -> CGSize {
        guard table.collecting, !reduceMotion, let winner = table.highlightedWinner,
              let target = table.seating.position(for: winner, in: size) else { return .zero }
        return CGSize(width: (target.x - size.width / 2) * 1.3, height: winner == table.view.player ? 55 : -55)
    }

    private var accessibilitySummary: String {
        let strings = preferences.strings
        var parts = [strings.text("Trick \(table.trick.number)")]
        if let suit = table.trick.leadSuit { parts.append(strings.text("Led suit: \(strings.suit(suit))")) }
        if table.trick.plays.isEmpty { parts.append(strings.text("No cards played yet.")) }
        parts += table.trick.plays.map { strings.text("\(strings.player($0.player, in: table.view)): \(strings.card($0.card))") }
        if let winner = table.highlightedWinner {
            parts.append(strings.text("Trick \(table.trick.number) · Winner: \(strings.player(winner, in: table.view))"))
        }
        return parts.joined(separator: ". ")
    }
}
