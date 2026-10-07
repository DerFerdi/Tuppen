import SwiftUI

struct GameView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @AppStorage("hasDiscoveredTableKnock") private var hasDiscoveredKnock = false
    @Namespace private var cardMotion
    private var strings: GameStrings { preferences.strings }

    var body: some View {
        GeometryReader { geometry in
            if let table = model.table {
                let compact = geometry.size.height < 700
                let handHeight = min(174, max(104, geometry.size.height * 0.27))
                VStack(spacing: compact ? 5 : 10) {
                    navigation.frame(height: 34).accessibilitySortPriority(100)
                    opponents(table).frame(height: compact ? 70 : 84)
                        .accessibilityElement(children: .contain)
                        .accessibilitySortPriority(90)
                    if table.resultVisible, case .finished(let outcome) = table.view.roundPhase {
                        RoundResultView(view: table.view, outcome: outcome, changes: model.presentedRoundChanges)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .accessibilitySortPriority(80)
                    } else {
                        playingSurface(table)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .layoutPriority(1)
                            .accessibilitySortPriority(80)
                        // Reserve the response space even when empty so decisions
                        // cannot move the trick or resize the hand.
                        ZStack {
                            Color.clear
                            context(table)
                                // The table stays bounded at large text sizes;
                                // VoiceOver retains the full prompt and hints.
                                .dynamicTypeSize(...DynamicTypeSize.xLarge)
                        }
                        .frame(height: 74)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(strings.text("Current decision"))
                        .accessibilityValue(model.isBusy ? strings.text("Play is in progress.") : strings.actionPrompt(in: table.view))
                        .accessibilitySortPriority(70)
                        HandView(cards: table.hand, namespace: cardMotion)
                            .frame(height: handHeight)
                            .accessibilitySortPriority(60)
                    }
                    if let human = table.players.first(where: { $0.id == table.view.player }) {
                        playerSummary(human, table: table, compact: true)
                            .frame(height: compact ? 30 : 38)
                            .accessibilitySortPriority(50)
                    }
                }
                .frame(maxWidth: 540)
                .padding(.horizontal, compact ? 16 : 24)
                .padding(.vertical, 8)
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .background(TableStyle.background.ignoresSafeArea())
        .tint(TableStyle.accent)
        .toolbar(.hidden, for: .navigationBar)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var navigation: some View {
        HStack {
            Button { model.path = [] } label: {
                Image(systemName: "chevron.left").font(.body.weight(.medium))
                    .frame(width: 44, height: 44, alignment: .leading)
            }
            .accessibilityLabel(strings.text("Back to Home"))
            Spacer()
            if model.isSkippingToResult {
                ProgressView().accessibilityLabel(strings.text("Finishing match…"))
            } else if model.canSkipToResult {
                Button { Task { await model.skipToResult() } } label: {
                    Text(strings.text("Skip to Result"))
                        .font(.subheadline).lineLimit(1).minimumScaleFactor(0.8)
                        .frame(minHeight: 44).contentShape(Rectangle())
                }
                .accessibilityHint(strings.text("Finish the remaining computer turns without animations."))
            }
            Menu {
                if model.canKnock {
                    Button(strings.text("Knock"), systemImage: "hand.tap") { knock() }
                }
                NavigationLink(strings.text("Settings"), value: AppScreen.settings)
                NavigationLink(strings.text("Statistics"), value: AppScreen.statistics)
            } label: {
                Image(systemName: "ellipsis").font(.body.weight(.medium))
                    .frame(width: 44, height: 44, alignment: .trailing)
            }
            .accessibilityLabel(strings.text("Table options"))
        }
        .foregroundStyle(.secondary)
    }

    private func opponents(_ table: TablePresentation) -> some View {
        HStack(alignment: .top, spacing: table.opponents.count == 3 ? 8 : 12) {
            ForEach(table.opponents, id: \.id) { player in
                playerSummary(player, table: table)
            }
        }
    }

    private func playerSummary(_ player: PublicPlayerState, table: TablePresentation, compact: Bool = false) -> some View {
        PlayerSummaryView(
            player: player, view: table.view,
            thinking: table.thinkingPlayer == player.id,
            highlighted: table.highlightedWinner == player.id,
            reaction: table.reactions[player.id],
            addedStrokes: table.strokeChanges.first(where: { $0.player == player.id })?.amount ?? 0,
            compact: compact,
            narrow: !compact && table.opponents.count == 3
        )
    }

    private func playingSurface(_ table: TablePresentation) -> some View {
        let motionReduced = reduceMotion
        return ZStack {
            TrickView(table: table, namespace: cardMotion)
            if table.reactions.values.contains(.knocked) {
                Text(strings.text("TOK TOK"))
                    .font(.system(.title2, design: .serif, weight: .semibold)).tracking(5)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(TableStyle.background.opacity(0.96), in: Capsule())
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
        }
        .animation(.easeInOut(duration: TablePacing.motionDuration(reduceMotion: reduceMotion)), value: table.reactions)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { if !voiceOverEnabled { knock() } }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(strings.text("Card table"))
        .accessibilityValue(strings.text("Stake: \(table.stake)"))
        .accessibilityActions {
            if model.canKnock { Button(strings.text("Knock")) { knock() } }
        }
        .keyframeAnimator(initialValue: 1.0, trigger: table.knockPulse) { content, scale in
            content.scaleEffect(motionReduced || table.knockPulse == 0 ? 1 : scale)
        } keyframes: { _ in
            LinearKeyframe(0.992, duration: TablePacing.motionDuration(reduceMotion: motionReduced) / 2)
            LinearKeyframe(1, duration: TablePacing.motionDuration(reduceMotion: motionReduced) / 2)
        }
    }

    @ViewBuilder private func context(_ table: TablePresentation) -> some View {
        if model.automaticWorkFailed {
            Button(strings.text("Retry")) { Task { await model.retry() } }
                .buttonStyle(.bordered).disabled(model.isBusy)
        } else if model.canSubmit(.respondToKnock(.hold)) {
            VStack(spacing: 8) {
                Text(responsePrompt(table))
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .lineLimit(1).minimumScaleFactor(0.8)
                HStack(spacing: 16) {
                    Button(strings.text("Hold")) { Task { await model.submit(.respondToKnock(.hold)) } }
                        .buttonStyle(.borderedProminent)
                        .foregroundStyle(TableStyle.onAccent)
                        .accessibilityHint(strings.text("Stay in this round at stake \(table.stake)."))
                    Button(strings.text("Pass")) { Task { await model.submit(.respondToKnock(.pass)) } }
                        .buttonStyle(.bordered)
                        .accessibilityHint(passHint(table))
                }
                .controlSize(.large)
            }
            .transition(.opacity)
        } else if let outcome = table.roundOutcome {
            Text(roundMessage(outcome, table: table))
                .font(.subheadline.weight(.medium)).multilineTextAlignment(.center)
                .transition(.opacity)
        } else if let winner = table.highlightedWinner {
            Text(strings.text("Trick \(table.trick.number) · Winner: \(strings.player(winner, in: table.view))"))
                .font(.subheadline.weight(.medium)).multilineTextAlignment(.center)
                .transition(.opacity)
        } else if voiceOverEnabled, model.canKnock {
            // VoiceOver reserves double tap for activation. This ordinary
            // button uses the same legality gate as the gesture and menu.
            Button(strings.text("Knock")) { knock() }.buttonStyle(.bordered)
                .controlSize(.large)
        } else if model.canKnock, !hasDiscoveredKnock, table.stake == 1 {
            Text(strings.text("Double tap the table to Knock"))
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        } else if table.stake > 1 {
            Text(strings.text("Stake: \(table.stake)"))
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
    }

    private func roundMessage(_ outcome: RoundOutcome, table: TablePresentation) -> String {
        if case .noActiveWinner = outcome { return strings.text("Everyone still in receives strokes.") }
        return strings.roundResult(outcome, in: table.view)
    }

    private func responsePrompt(_ table: TablePresentation) -> String {
        if case .awaitingResponses(let pending) = table.view.roundPhase {
            return strings.text("\(strings.player(pending.player, in: table.view)) knocked. Stake: \(table.stake)")
        }
        return strings.text("Stake: \(table.stake)")
    }

    private func knock() {
        guard model.canKnock else { return }
        hasDiscoveredKnock = true
        Task { await model.submit(.knock) }
    }

    private func passHint(_ table: TablePresentation) -> String {
        guard case .awaitingResponses(let pending) = table.view.roundPhase else { return "" }
        return strings.text("Leave this round and receive \(pending.previousStake) strokes.")
    }
}
