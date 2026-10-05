import SwiftUI

struct TrickView: View {
    let table: TablePresentation
    let namespace: Namespace.ID
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let cardWidth = min(88, min(size.width * 0.24, size.height * 0.43))
            ZStack {
                Ellipse()
                    .fill(.primary.opacity(0.025))
                    .frame(width: size.width * 0.91, height: size.height * 0.85)
                    .position(x: size.width / 2, y: size.height / 2)
                    .accessibilityHidden(true)
                // Fixed seat positions also retain cards committed by a player
                // who has passed. Participation never filters the public trick.
                ForEach(table.trick.plays, id: \.player) { play in
                    playedCard(play, width: cardWidth)
                        .position(position(for: play.player, in: size))
                        .offset(collectionOffset(in: size))
                        .opacity(table.collecting ? 0 : 1)
                }
            }
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
        .rotationEffect(.degrees(reduceMotion ? 0 : angle(for: play.player)))
        .zIndex(highlighted ? 1 : 0)
        .transition(reduceMotion ? .opacity : .offset(x: 0, y: play.player == table.view.player ? 45 : -35).combined(with: .opacity))
        .accessibilityLabel(preferences.strings.text("\(preferences.strings.player(play.player, in: table.view)): \(preferences.strings.card(play.card))"))
        .accessibilityValue(highlighted ? preferences.strings.text("Trick winner") : "")
    }

    private func position(for player: PlayerID, in size: CGSize) -> CGPoint {
        if player == table.view.player { return CGPoint(x: size.width * 0.5, y: size.height * 0.67) }
        let firstOpponent = table.players.first { $0.id != table.view.player }?.id
        return CGPoint(x: size.width * (player == firstOpponent ? 0.30 : 0.70), y: size.height * 0.34)
    }

    private func angle(for player: PlayerID) -> Double {
        if player == table.view.player { return 2 }
        return player == table.players.first(where: { $0.id != table.view.player })?.id ? -5 : 5
    }

    private func collectionOffset(in size: CGSize) -> CGSize {
        guard table.collecting, !reduceMotion, let winner = table.highlightedWinner else { return .zero }
        let target = position(for: winner, in: size)
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
