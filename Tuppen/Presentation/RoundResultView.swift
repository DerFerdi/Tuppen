import SwiftUI

struct RoundResultView: View {
    let view: PlayerView
    let outcome: RoundOutcome
    let changes: [StrokeChange]
    @Environment(AppModel.self) private var model
    @Environment(AppPreferences.self) private var preferences
    private var strings: GameStrings { preferences.strings }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 350
            result(compact: compact)
                .frame(maxWidth: 360)
                .padding(.horizontal, 8)
                .frame(width: geometry.size.width, height: geometry.size.height)
                // Preserve a readable result and reachable actions in the same
                // bounded table space, including the longer German outcome.
                .dynamicTypeSize(...(compact ? DynamicTypeSize.xLarge : .xxxLarge))
        }
        .disabled(model.isBusy)
        .transition(.opacity)
    }

    private func result(compact: Bool) -> some View {
        VStack(spacing: compact ? 10 : 18) {
            Text(title)
                .font(.system(compact ? .title2 : .title, design: .serif, weight: .medium))
                .lineLimit(2).minimumScaleFactor(0.85)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel(view.matchPhase == .playing ? title : strings.matchResult(in: view))
            if case .noActiveWinner = outcome {
                Text(strings.text("The winner passed. Strokes for everyone still in."))
                    .font(.callout).foregroundStyle(.secondary)
            } else if case .won(_, .opponentsPassed) = outcome {
                Text(strings.text("Everyone else passed."))
                    .font(.callout).foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 18) {
                ForEach(changes.filter { $0.amount > 0 }, id: \.player) { change in
                    VStack(spacing: 4) {
                        Text(strings.text("+\(change.amount)"))
                            .font(.system(.title3, design: .serif, weight: .medium)).monospacedDigit()
                        Text(strings.player(change.player, in: view))
                            .font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(strings.announcement(.strokesAdded(player: change.player, amount: change.amount), in: view))
                }
            }
            .padding(.bottom, 4)
            if view.matchPhase == .playing {
                if view.players.first(where: { $0.id == view.player })?.status == .eliminated {
                    Text(strings.text("The opponents play on."))
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    Button(strings.text("Next Round")) { Task { await model.nextRound() } }
                        .buttonStyle(.borderedProminent)
                        .foregroundStyle(TableStyle.onAccent)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 20) { matchActions }
                    VStack(spacing: 12) { matchActions }
                }
            }
        }
        .controlSize(.large)
        .multilineTextAlignment(.center)
    }

    @ViewBuilder private var matchActions: some View {
        Button(strings.text("New Game")) { Task { await model.newMatch() } }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(TableStyle.onAccent)
        Button { model.path = [] } label: {
            Text(strings.text("Home")).frame(minHeight: 44).contentShape(Rectangle())
        }
        .foregroundStyle(.secondary)
    }

    private var title: String {
        switch view.matchPhase {
        case .playing:
            if case .noActiveWinner = outcome { strings.text("Round Complete") }
            else { strings.roundResult(outcome, in: view) }
        case .finished(let winner):
            winner == view.player ? strings.text("You Win") : strings.text("\(strings.player(winner, in: view)) Wins")
        case .draw: strings.text("Draw")
        }
    }
}
