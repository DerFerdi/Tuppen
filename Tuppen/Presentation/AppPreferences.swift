import Foundation
import Observation

enum AppLanguage: String, CaseIterable, Sendable {
    case system
    case german = "de"
    case english = "en"

    func locale(preferredLanguages: [String] = Locale.preferredLanguages) -> Locale {
        let identifier = self == .system
            ? Bundle.preferredLocalizations(from: ["en", "de"], forPreferences: preferredLanguages).first ?? "en"
            : rawValue
        return Locale(identifier: identifier)
    }
}

/// Preferences have no session reference: changing language or effect settings
/// cannot recreate a match or alter an in-flight game decision.
@MainActor @Observable
final class AppPreferences {
    private let defaults: UserDefaults

    var language: AppLanguage { didSet { defaults.set(language.rawValue, forKey: "language") } }
    var soundEnabled: Bool { didSet { defaults.set(soundEnabled, forKey: "soundEnabled") } }
    var hapticsEnabled: Bool { didSet { defaults.set(hapticsEnabled, forKey: "hapticsEnabled") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: ["language": "system", "soundEnabled": true, "hapticsEnabled": true])
        language = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "") ?? .system
        soundEnabled = defaults.bool(forKey: "soundEnabled")
        hapticsEnabled = defaults.bool(forKey: "hapticsEnabled")
    }

    var locale: Locale { language.locale() }
    var strings: GameStrings { GameStrings(locale: locale) }
}
