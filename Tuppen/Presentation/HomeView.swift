import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppPreferences.self) private var preferences
    @State private var confirmingNewMatch = false
    private var strings: GameStrings { preferences.strings }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                content.frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(TableStyle.background.ignoresSafeArea())
        .tint(TableStyle.accent)
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog(strings.text("Start a New Game?"), isPresented: $confirmingNewMatch, titleVisibility: .visible) {
            Button(strings.text("New Game"), role: .destructive) { Task { await model.newMatch() } }
            Button(strings.text("Cancel"), role: .cancel) {}
        } message: {
            Text(strings.text("This replaces your current match. Your statistics are kept."))
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 28)
            Text(strings.text("TUPPEN"))
                .font(.system(size: 42, weight: .medium, design: .serif)).tracking(7)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 56)
            VStack(spacing: 18) {
                if model.hasActiveMatch {
                    Button(strings.text("Continue")) { model.path = [.game] }
                        .buttonStyle(.borderedProminent)
                        .foregroundStyle(TableStyle.onAccent)
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
                ProgressView(strings.text("Loading…")).padding(.top, 24)
            } else if model.hasLoaded, model.snapshot == nil {
                VStack(spacing: 12) {
                    Text(strings.failure(.restore))
                        .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    if model.canRetryRestore {
                        Button(strings.text("Retry")) { Task { await model.retryRestore() } }
                            .buttonStyle(.bordered).controlSize(.large)
                    }
                }
                .padding(.top, 24)
            }
            Spacer(minLength: 32)
            VStack(spacing: 8) {
                NavigationLink(value: AppScreen.tutorial) {
                    Text(strings.text("How to Play")).frame(minHeight: 44).contentShape(Rectangle())
                }
                NavigationLink(value: AppScreen.statistics) {
                    Text(strings.text("Statistics")).frame(minHeight: 44).contentShape(Rectangle())
                }
                NavigationLink(value: AppScreen.settings) {
                    Text(strings.text("Settings")).frame(minHeight: 44).contentShape(Rectangle())
                }
            }
            .font(.subheadline).foregroundStyle(.secondary)
            .padding(.bottom, 36)
        }
        .frame(maxWidth: 380).padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }
}
