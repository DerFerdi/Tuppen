import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppPreferences.self) private var preferences
    @State private var confirmingReset = false
    private var strings: GameStrings { preferences.strings }

    var body: some View {
        @Bindable var preferences = preferences
        Form {
            Section {
                Picker(strings.text("Language"), selection: $preferences.language) {
                    Text(strings.text("System")).tag(AppLanguage.system)
                    Text(strings.text("Deutsch")).tag(AppLanguage.german)
                    Text(strings.text("English")).tag(AppLanguage.english)
                }
            }
            Section {
                Toggle(strings.text("Sound"), isOn: $preferences.soundEnabled)
                Toggle(strings.text("Haptics"), isOn: $preferences.hapticsEnabled)
            } footer: {
                Text(strings.text("Your preferences are saved. Sound and haptic effects will be available in a future update."))
            }
            Section {
                Button(strings.text("Reset Statistics"), role: .destructive) { confirmingReset = true }
                    .disabled(model.isBusy || model.snapshot == nil)
            }
        }
        .navigationTitle(strings.text("Settings"))
        .confirmationDialog(strings.text("Reset All Statistics?"), isPresented: $confirmingReset, titleVisibility: .visible) {
            Button(strings.text("Reset Statistics"), role: .destructive) { Task { await model.resetStatistics() } }
            Button(strings.text("Cancel"), role: .cancel) {}
        } message: {
            Text(strings.text("This clears your local statistics. Your current match is kept."))
        }
    }
}
