import SwiftUI

/// Reads the saved selection, never the mutable New Game draft.
struct MatchInformationView: View {
    let update: SessionUpdate
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    private var strings: GameStrings { preferences.strings }

    var body: some View {
        NavigationStack {
            List {
                if let view = update.view {
                    Section {
                        if let count = update.botCount {
                            LabeledContent(strings.text("Computer Opponents"), value: strings.opponents(count))
                        }
                        if let difficulty = update.difficulty {
                            LabeledContent(strings.text("Difficulty"), value: strings.difficulty(difficulty))
                        }
                    }
                    Section(strings.text("House Rules")) {
                        LabeledContent(strings.text("Maximum strokes"), value:
                            view.houseRules.maximumStrokes.rawValue.formatted(.number.locale(preferences.locale)))
                        ForEach(HouseRuleOption.allCases) { option in
                            LabeledContent(strings.text(option.title), value:
                                strings.text(option.isEnabled(in: view.houseRules) ? "On" : "Off"))
                        }
                    }
                    if !view.knownHands.isEmpty {
                        Section(strings.text("Publicly known cards")) {
                            // Only retained public knowledge is current. Historical
                            // revelations may describe an already exchanged hand.
                            ForEach(view.knownHands, id: \.player) { hand in
                                LabeledContent(strings.player(hand.player, in: view), value:
                                    hand.cards.map(strings.card).joined(separator: ", "))
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(TableStyle.background)
            .navigationTitle(strings.text("Match Information"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(strings.text("Done")) { dismiss() }
                }
            }
        }
        .tint(TableStyle.accent)
    }
}
