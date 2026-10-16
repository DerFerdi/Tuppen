import SwiftUI

struct StrokeMarksView: View {
    let strokes: Int
    var maximum: MaximumStrokes = .seven
    @Environment(AppPreferences.self) private var preferences

    var body: some View {
        // Two short rows keep ten marks beside eight card backs in narrow seats.
        VStack(spacing: 3) {
            ForEach(0..<(maximum == .ten ? 2 : 1), id: \.self) { row in
                HStack(spacing: 5) {
                    ForEach(0..<(maximum == .ten ? 5 : 7), id: \.self) { column in
                        let index = row * 5 + column
                        Capsule()
                            .fill(index < strokes ? Color.primary : .clear)
                            .overlay { Capsule().stroke(.primary.opacity(0.25), lineWidth: 1) }
                            .frame(width: 3, height: 12)
                            .rotationEffect(.degrees(12))
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(preferences.strings.strokes(strokes, maximum: maximum))
    }
}
