import SwiftUI

struct TutorialView: View {
    @Environment(AppPreferences.self) private var preferences
    private var strings: GameStrings { preferences.strings }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                ForEach(TutorialStep.allCases) { step in
                    VStack(alignment: .leading, spacing: 14) {
                        Text(strings.text(step.title))
                            .font(.system(.title2, design: .serif, weight: .medium))
                            .accessibilityAddTraits(.isHeader)
                        illustration(step).accessibilityHidden(true)
                        Text(strings.text(step.explanation))
                            .font(.body).fixedSize(horizontal: false, vertical: true)
                        if step == .knock {
                            Text(strings.text("Double tap the table to Knock"))
                                .font(.body.weight(.medium))
                        }
                    }
                    .padding(step == .finalTrick ? 16 : 0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        if step == .finalTrick {
                            RoundedRectangle(cornerRadius: 12).fill(TableStyle.accent.opacity(0.08))
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(TableStyle.background)
        .tint(TableStyle.accent)
        .navigationTitle(strings.text("How to Play"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    // Examples repeat the prose visually; VoiceOver reads the complete rules
    // once instead of traversing decorative cards and stroke marks.
    @ViewBuilder private func illustration(_ step: TutorialStep) -> some View {
        switch step {
        case .cards:
            HStack(spacing: 10) {
                ForEach(Suit.allCases, id: \.self) { suit in
                    CardView(card: Card(suit: suit, rank: .ace)).frame(maxWidth: 64)
                }
            }
        case .ranks:
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 54, maximum: 72))], alignment: .leading, spacing: 10) {
                ForEach(Rank.allCases, id: \.self) { rank in
                    CardView(card: Card(suit: .hearts, rank: rank))
                }
            }
        case .followingSuit:
            HStack(spacing: 12) {
                CardView(card: Card(suit: .hearts, rank: .king))
                CardView(card: Card(suit: .hearts, rank: .ten))
            }
            .frame(width: 140)
        case .finalTrick:
            HStack(spacing: 12) {
                ForEach(1...4, id: \.self) { number in
                    Text(number.formatted(.number.locale(preferences.locale)))
                        .font(.title2.weight(number == 4 ? .bold : .regular))
                        .frame(minWidth: 36, minHeight: 44)
                        .overlay(alignment: .bottom) {
                            if number == 4 { Capsule().frame(height: 3) }
                        }
                }
            }
        case .strokes:
            StrokeMarksView(strokes: 7)
        case .knock:
            Text(strings.text("TOK TOK"))
                .font(.system(.title3, design: .serif)).tracking(3)
        case .hold, .pass:
            EmptyView()
        }
    }
}
