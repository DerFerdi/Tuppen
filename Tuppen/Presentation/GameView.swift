import SwiftUI

struct GameView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppPreferences.self) private var preferences
    private var strings: GameStrings { preferences.strings }

    var body: some View {
        ScrollView {
            if let view = model.view {
                VStack(spacing: 22) {
                    HStack {
                        Text(strings.text("Round \(view.roundNumber)"))
                        Spacer()
                        Text(strings.text("Trick \(view.currentTrick.number) of 4"))
                        Spacer()
                        Text(strings.text("Stake: \(view.stake)"))
                    }
                    .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(view.players.filter { $0.id != view.player }, id: \.id) { player in
                            PlayerSummaryView(player: player, view: view)
                        }
                    }
                    TrickView(view: view)
                    if case .finished(let outcome) = view.roundPhase {
                        RoundResultView(view: view, outcome: outcome, changes: model.snapshot?.roundChanges ?? [])
                    } else {
                        turnStatus(view)
                        hand(view)
                        actions(view)
                    }
                    if let human = view.players.first(where: { $0.id == view.player }) {
                        PlayerSummaryView(player: human, view: view)
                        if human.status == .eliminated, view.matchPhase == .playing {
                            Text(strings.text("You are eliminated. The opponents will finish the match."))
                                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                    }
                    if model.automaticWorkFailed {
                        Button(strings.text("Retry")) { Task { await model.resume() } }
                            .buttonStyle(.bordered).disabled(model.isBusy)
                    }
                    RoundHistoryView(view: view)
                }
                .frame(maxWidth: 500).frame(maxWidth: .infinity).padding(20)
            }
        }
        .navigationTitle(strings.text("TUPPEN"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            NavigationLink(value: AppScreen.settings) {
                Label(strings.text("Settings"), systemImage: "gearshape")
            }
        }
    }

    @ViewBuilder
    private func turnStatus(_ view: PlayerView) -> some View {
        switch view.roundPhase {
        case .playing(let turn):
            if turn.player == view.player {
                Text(strings.text("Your turn. Choose a card.")).font(.headline)
            } else {
                Text(strings.text("\(strings.player(turn.player, in: view)) is playing."))
                    .font(.headline)
            }
        case .awaitingResponses(let pending):
            VStack(spacing: 6) {
                Text(strings.text("\(strings.player(pending.player, in: view)) knocked. Stake: \(view.stake)"))
                    .font(.headline)
                if let responder = pending.expectedResponder, responder != view.player {
                    Text(strings.text("Waiting for \(strings.player(responder, in: view))."))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.center)
        case .finished: EmptyView()
        }
    }

    private func hand(_ view: PlayerView) -> some View {
        HStack(spacing: 10) {
            ForEach(view.hand, id: \.self) { card in
                let action = GameAction.playCard(card)
                let legal = view.legalActions.contains(action)
                Button { Task { await model.submit(action) } } label: {
                    CardView(card: card)
                        .overlay {
                            if legal {
                                RoundedRectangle(cornerRadius: 10).stroke(.tint, lineWidth: 2)
                            }
                        }
                        .opacity(legal ? 1 : 0.65)
                }
                .buttonStyle(.plain)
                .disabled(!legal || model.isBusy)
                .accessibilityLabel(strings.card(card))
                .accessibilityHint(legal ? strings.text("Play this card") : strings.text("Currently unavailable"))
                .frame(maxWidth: 88)
            }
        }
    }

    private func actions(_ view: PlayerView) -> some View {
        HStack(spacing: 16) {
            if model.isBusy { ProgressView().accessibilityLabel(strings.text("Playing…")) }
            if view.legalActions.contains(.knock) {
                Button(strings.text("Knock")) { Task { await model.submit(.knock) } }
                    .buttonStyle(.bordered)
            }
            if view.legalActions.contains(.respondToKnock(.hold)) {
                Button(strings.text("Hold")) { Task { await model.submit(.respondToKnock(.hold)) } }
                    .buttonStyle(.borderedProminent)
            }
            if view.legalActions.contains(.respondToKnock(.pass)) {
                Button(strings.text("Pass")) { Task { await model.submit(.respondToKnock(.pass)) } }
                    .buttonStyle(.bordered)
            }
        }
        .controlSize(.large).disabled(model.isBusy)
    }
}
