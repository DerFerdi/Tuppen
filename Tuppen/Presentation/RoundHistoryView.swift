import SwiftUI

/// Committed public history keeps fast bot responses inspectable without delays
/// in the rules or a dependency on transient event messages.
struct RoundHistoryView: View {
    let view: PlayerView
    @Environment(AppPreferences.self) private var preferences
    private var strings: GameStrings { preferences.strings }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let knock = view.knocks.last { knockSummary(knock) }
            if let trick = view.completedTricks.last {
                Text(strings.text("Trick \(trick.trick.number) · Winner: \(strings.player(trick.winner, in: view))"))
                    .font(.subheadline)
            }
            if !view.completedTricks.isEmpty || view.knocks.count > 1 {
                DisclosureGroup(strings.text("Round History")) {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(Array(view.knocks.enumerated()), id: \.offset) { _, knock in knockSummary(knock) }
                        ForEach(view.completedTricks, id: \.trick.number) { completed in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(strings.text("Trick \(completed.trick.number) · Winner: \(strings.player(completed.winner, in: view))"))
                                    .font(.subheadline)
                                HStack(alignment: .top, spacing: 12) {
                                    ForEach(completed.trick.plays, id: \.player) { play in
                                        VStack(spacing: 4) {
                                            CardView(card: play.card).frame(width: 48)
                                            Text(strings.player(play.player, in: view)).font(.caption2)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 12)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func knockSummary(_ knock: KnockRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(strings.text("\(strings.player(knock.player, in: view)) knocked. Stake: \(knock.raisedStake)"))
                .font(.subheadline.weight(.medium))
            ForEach(knock.responses, id: \.player) { response in
                Text(response.response == .hold
                     ? strings.text("\(strings.player(response.player, in: view)): Hold")
                     : strings.text("\(strings.player(response.player, in: view)): Pass"))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
