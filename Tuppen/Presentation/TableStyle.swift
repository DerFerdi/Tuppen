import SwiftUI

enum TableStyle {
    static var background: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.10, green: 0.12, blue: 0.14, alpha: 1)
                : UIColor(red: 0.95, green: 0.94, blue: 0.91, alpha: 1)
        })
    }

    static var accent: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.69, green: 0.79, blue: 0.75, alpha: 1)
                : UIColor(red: 0.19, green: 0.32, blue: 0.29, alpha: 1)
        })
    }

    static let paper = Color(red: 0.995, green: 0.99, blue: 0.965)

    // The dark appearance uses a light accent. Explicit ink avoids white text
    // on that pale fill in prominent buttons.
    static var onAccent: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.10, green: 0.12, blue: 0.14, alpha: 1) : .white
        })
    }
}

/// Press feedback stays local to the card. Only the button's action can submit
/// an intention; interrupting this visual never changes the match.
struct CardPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: TablePacing.motionDuration(reduceMotion: reduceMotion)), value: configuration.isPressed)
    }
}
