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
            }
            Section {
                Link(destination: URL(string: "https://derferdi.github.io/Tuppen/privacy/")!) {
                    HStack {
                        Text(strings.text("Privacy Policy"))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.footnote)
                            .accessibilityHidden(true)
                    }
                }
                Button(strings.text("Reset Statistics"), role: .destructive) { confirmingReset = true }
                    .disabled(model.isBusy || model.snapshot == nil)
            }
        }
        .scrollContentBackground(.hidden)
        .background(TableStyle.background)
        .tint(TableStyle.accent)
        .navigationTitle(strings.text("Settings"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .confirmationDialog(strings.text("Reset All Statistics?"), isPresented: $confirmingReset, titleVisibility: .visible) {
            Button(strings.text("Reset Statistics"), role: .destructive) { Task { await model.resetStatistics() } }
            Button(strings.text("Cancel"), role: .cancel) {}
        } message: {
            Text(strings.text("This clears your local statistics. Your current match is kept."))
        }
    }
}
