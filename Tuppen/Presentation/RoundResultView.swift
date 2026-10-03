import SwiftUI

struct RoundResultView: View {
    let view: PlayerView
    let outcome: RoundOutcome
    let changes: [StrokeChange]
    @Environment(AppModel.self) private var model
    @Environment(AppPreferences.self) private var preferences
    private var strings: GameStrings { preferences.strings }

    var body: some View {
        VStack(spacing: 16) {
            switch view.matchPhase {
            case .playing:
                Text(strings.text("Round Complete")).font(.title2.weight(.semibold))
            case .finished(let winner):
                Text(winner == view.player ? strings.text("You Win") : strings.text("\(strings.player(winner, in: view)) Wins"))
                    .font(.title.weight(.semibold))
            case .draw:
                Text(strings.text("Draw")).font(.title.weight(.semibold))
            }
            Text(strings.roundResult(outcome, in: view))
            if case .noActiveWinner = outcome {
                Text(strings.text("The winning card belongs to a player who passed. All remaining players receive strokes."))
                    .font(.callout).foregroundStyle(.secondary)
            }
            VStack(spacing: 10) {
                ForEach(changes, id: \.player) { change in
                    VStack(spacing: 3) {
                        Text(strings.text("\(strings.player(change.player, in: view)): Strokes +\(change.amount)"))
                            .monospacedDigit()
                        if view.players.first(where: { $0.id == change.player })?.status == .eliminated {
                            Text(strings.text("Eliminated")).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if view.matchPhase == .playing {
                Button(strings.text("Next Round")) { Task { await model.nextRound() } }
                    .buttonStyle(.borderedProminent)
            } else {
                Button(strings.text("New Game")) { Task { await model.newMatch() } }
                    .buttonStyle(.borderedProminent)
                Button(strings.text("Back to Home")) { model.path = [] }
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity).padding(20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
        .disabled(model.isBusy)
    }
}
