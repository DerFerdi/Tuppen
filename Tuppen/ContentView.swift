import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.path) {
            HomeView()
                .navigationDestination(for: AppScreen.self) { screen in
                    switch screen {
                    case .game: GameView()
                    case .statistics: StatisticsView()
                    case .settings: SettingsView()
                    }
                }
        }
        .task { await model.load() }
        .onChange(of: model.path) { _, path in
            if path.last == .game { Task { await model.resume() } }
        }
        .onChange(of: scenePhase) { _, phase in
            model.sceneIsActive = phase == .active
            if phase == .active { Task { await model.resume() } }
        }
        .alert(preferences.strings.text("Unable to Continue"), isPresented: Binding(
            get: { model.failure != nil },
            set: { if !$0 { model.dismissFailure() } }
        )) {
            Button(preferences.strings.text("Retry")) { Task { await model.retry() } }
            Button(preferences.strings.text("OK"), role: .cancel) { model.dismissFailure() }
        } message: {
            if let failure = model.failure { Text(preferences.strings.failure(failure)) }
        }
    }
}
