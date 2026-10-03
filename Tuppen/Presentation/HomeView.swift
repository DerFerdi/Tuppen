import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppPreferences.self) private var preferences
    @State private var confirmingNewMatch = false
    private var strings: GameStrings { preferences.strings }

    var body: some View {
        ScrollView {
            VStack(spacing: 36) {
                VStack(spacing: 16) {
                    Image(systemName: "suit.club.fill")
                        .font(.system(size: 40)).foregroundStyle(.tint).accessibilityHidden(true)
                    Text(strings.text("TUPPEN"))
                        .font(.system(.largeTitle, design: .serif, weight: .semibold)).tracking(5)
                        .accessibilityAddTraits(.isHeader)
                    Text(strings.text("Four cards. One final trick."))
                        .foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .padding(.top, 48)
                VStack(spacing: 16) {
                    if model.hasActiveMatch {
                        Button(strings.text("Continue")) { model.path = [.game] }
                            .buttonStyle(.borderedProminent)
                    }
                    Button(strings.text("New Game")) {
                        if model.hasActiveMatch { confirmingNewMatch = true }
                        else { Task { await model.newMatch() } }
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)
                .disabled(!model.hasLoaded || model.isBusy)
                if model.isBusy {
                    ProgressView(strings.text("Loading…"))
                } else if model.hasLoaded, model.snapshot == nil {
                    Text(strings.text("Your saved game could not be opened. Try again, or start a new game to replace it."))
                        .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                VStack(spacing: 22) {
                    NavigationLink(strings.text("Statistics"), value: AppScreen.statistics)
                    NavigationLink(strings.text("Settings"), value: AppScreen.settings)
                }
                .disabled(!model.hasLoaded)
            }
            .frame(maxWidth: 440).frame(maxWidth: .infinity).padding(24)
        }
        .navigationTitle(strings.text("Home"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(strings.text("Start a New Game?"), isPresented: $confirmingNewMatch, titleVisibility: .visible) {
            Button(strings.text("New Game"), role: .destructive) { Task { await model.newMatch() } }
            Button(strings.text("Cancel"), role: .cancel) {}
        } message: {
            Text(strings.text("This replaces your current match. Your statistics are kept."))
        }
    }
}
