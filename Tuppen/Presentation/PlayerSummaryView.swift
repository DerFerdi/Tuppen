import SwiftUI

struct PlayerSummaryView: View {
    let player: PublicPlayerState
    let view: PlayerView
    var thinking = false
    var highlighted = false
    var reaction: TableReaction?
    var addedStrokes = 0
    var compact = false
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var strings: GameStrings { preferences.strings }

    var body: some View {
        Group {
            if compact {
                HStack(spacing: 12) {
                    name
                    StrokeMarksView(strokes: player.strokes).fixedSize()
                    reactionLabel
                }
            } else {
                VStack(spacing: 7) {
                    name
                    HStack(spacing: 10) {
                        cardBacks
                        StrokeMarksView(strokes: player.strokes)
                    }
                    reactionLabel.frame(height: 18)
                }
            }
        }
        .foregroundStyle(player.status == .eliminated ? .secondary : .primary)
        .dynamicTypeSize(...(compact ? DynamicTypeSize.xLarge : .xxLarge))
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var name: some View {
        HStack(spacing: 5) {
            if thinking || highlighted {
                Image(systemName: highlighted ? "checkmark" : "ellipsis")
                    .font(.caption2.weight(.semibold))
                    .accessibilityLabel(thinking ? strings.text("Thinking") : strings.text("Trick winner"))
            }
            Text(strings.player(player.id, in: view))
                .font(.subheadline.weight(highlighted ? .semibold : .regular))
                .lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    private var cardBacks: some View {
        HStack(spacing: -7) {
            ForEach(0..<player.remainingCardCount, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 2)
                    .fill(TableStyle.accent.opacity(player.isParticipating ? 0.8 : 0.25))
                    .overlay { RoundedRectangle(cornerRadius: 2).stroke(TableStyle.background, lineWidth: 1.5) }
                    .frame(width: 12, height: 18)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(strings.text("Cards: \(player.remainingCardCount)"))
    }

    @ViewBuilder private var reactionLabel: some View {
        HStack(spacing: 6) {
            if addedStrokes > 0 {
                Text(strings.text("+\(addedStrokes)"))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .accessibilityLabel(strings.text("Strokes +\(addedStrokes)"))
                    .id(addedStrokes)
                    .transition(.opacity)
            }
            if let label = stateLabel {
                Text(label).font(.caption2.weight(.medium)).tracking(0.6)
                    .lineLimit(1).minimumScaleFactor(0.75)
                    .id(label)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: TablePacing.motionDuration(reduceMotion: reduceMotion)), value: addedStrokes)
        .animation(.easeInOut(duration: TablePacing.motionDuration(reduceMotion: reduceMotion)), value: stateLabel)
    }

    private var stateLabel: String? {
        switch reaction {
        case .knocked: strings.text("TOK TOK")
        case .held: strings.text("HOLDS")
        case .passed: strings.text("PASSES")
        case .eliminated: strings.text("Eliminated")
        case nil:
            if player.status == .eliminated { strings.text("Eliminated") }
            else if !player.isParticipating { strings.text("Passed") }
            else { nil }
        }
    }
}
