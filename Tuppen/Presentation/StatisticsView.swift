import SwiftUI

struct StatisticsView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppPreferences.self) private var preferences
    private var strings: GameStrings { preferences.strings }

    var body: some View {
        List {
            if model.snapshot != nil {
                ForEach(StatisticItem.items(in: model.statistics)) { item in
                    row(item.title, item.value)
                }
            } else {
                Text(strings.text("Statistics are unavailable until your saved data is opened or a new game is started."))
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(TableStyle.background)
        .tint(TableStyle.accent)
        .navigationTitle(strings.text("Statistics"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private func row(_ title: String.LocalizationValue, _ value: Int) -> some View {
        LabeledContent(strings.text(title), value: value.formatted(.number.locale(preferences.locale)))
            .accessibilityElement(children: .combine)
    }
}
