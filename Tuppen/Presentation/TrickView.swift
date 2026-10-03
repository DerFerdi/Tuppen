import SwiftUI

struct TrickView: View {
    let view: PlayerView
    @Environment(AppPreferences.self) private var preferences

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 36) {
                ForEach(view.players.filter { $0.id != view.player }, id: \.id) { player in
                    slot(for: player.id)
                }
            }
            slot(for: view.player)
        }
        .padding(18).frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24))
    }

    private func slot(for player: PlayerID) -> some View {
        VStack(spacing: 6) {
            Text(preferences.strings.player(player, in: view)).font(.caption).foregroundStyle(.secondary)
            if let play = view.currentTrick.plays.first(where: { $0.player == player }) {
                CardView(card: play.card).frame(width: 58)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .frame(width: 58, height: 83).accessibilityHidden(true)
            }
        }
    }
}
