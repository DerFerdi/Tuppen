import SwiftUI

struct PlayerSummaryView: View {
    let player: PublicPlayerState
    let view: PlayerView
    @Environment(AppPreferences.self) private var preferences

    var body: some View {
        let strings = preferences.strings
        VStack(spacing: 5) {
            Text(strings.player(player.id, in: view)).font(.headline)
            Text(strings.text("Strokes: \(player.strokes)")).font(.subheadline.monospacedDigit())
            if player.status == .eliminated {
                Text(strings.text("Eliminated")).font(.caption).foregroundStyle(.secondary)
            } else if !player.isParticipating {
                Text(strings.text("Passed")).font(.caption).foregroundStyle(.secondary)
            } else if player.id != view.player {
                Label(strings.text("Cards: \(player.remainingCardCount)"), systemImage: "rectangle.stack")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
