import SwiftUI

/// A per-match choice; dismissing this sheet never changes a checkpoint.
struct NewMatchView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var confirmingReplacement = false
    private var strings: GameStrings { preferences.strings }

    var body: some View {
        NavigationStack {
            List {
                Section(strings.text("Computer Opponents")) {
                    ForEach(BotCount.allCases, id: \.self) { count in
                        Button { model.newMatchBotCount = count } label: {
                            HStack {
                                Text(strings.opponents(count)).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "checkmark")
                                    .opacity(model.newMatchBotCount == count ? 1 : 0)
                                    .accessibilityHidden(true)
                            }
                            .frame(minHeight: 36)
                            .contentShape(Rectangle())
                        }
                        .accessibilityAddTraits(model.newMatchBotCount == count ? .isSelected : [])
                    }
                }
                Section(strings.text("Difficulty")) {
                    ForEach(BotDifficulty.allCases, id: \.self) { difficulty in
                        Button { model.newMatchDifficulty = difficulty } label: {
                            HStack {
                                Text(strings.difficulty(difficulty)).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "checkmark")
                                    .opacity(model.newMatchDifficulty == difficulty ? 1 : 0)
                                    .accessibilityHidden(true)
                            }
                            .frame(minHeight: 36)
                            .contentShape(Rectangle())
                        }
                        .accessibilityAddTraits(model.newMatchDifficulty == difficulty ? .isSelected : [])
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(TableStyle.background)
            .safeAreaInset(edge: .bottom) {
                Button(strings.text("Start Game")) {
                    if model.hasActiveMatch { confirmingReplacement = true }
                    else { Task { await model.newMatch() } }
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(TableStyle.onAccent)
                .controlSize(.large)
                .padding()
                .frame(maxWidth: .infinity)
                .background(TableStyle.background)
            }
            .navigationTitle(strings.text("New Game"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(strings.text("Cancel")) { model.isChoosingNewMatch = false }
                }
            }
            .disabled(model.isBusy)
            .confirmationDialog(strings.text("Start a New Game?"), isPresented: $confirmingReplacement, titleVisibility: .visible) {
                Button(strings.text("Start Game"), role: .destructive) { Task { await model.newMatch() } }
                Button(strings.text("Cancel"), role: .cancel) {}
            } message: {
                Text(strings.text("This replaces your current match. Your statistics are kept."))
            }
        }
        .tint(TableStyle.accent)
        // Larger text gets the full sheet and native list scrolling, while the
        // start action remains reachable below the choices.
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(580), .large])
        .presentationDragIndicator(.visible)
    }
}
