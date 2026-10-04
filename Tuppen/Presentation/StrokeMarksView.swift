import SwiftUI

struct StrokeMarksView: View {
    let strokes: Int
    @Environment(AppPreferences.self) private var preferences

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<7, id: \.self) { index in
                Capsule()
                    .fill(index < strokes ? Color.primary : .clear)
                    .overlay { Capsule().stroke(.primary.opacity(0.25), lineWidth: 1) }
                    .frame(width: 3, height: 12)
                    .rotationEffect(.degrees(12))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(preferences.strings.text("Strokes: \(strokes)"))
    }
}
