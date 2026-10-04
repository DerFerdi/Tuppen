import AVFoundation
import Foundation
import OSLog
import UIKit

/// Effects accompany public presentation beats; they never change a session.
/// Each knock call is one tap. The table timeline owns the two-tap rhythm.
enum TableEffect: Equatable, Sendable {
    case deal
    case cardPlaced
    case knockTap(human: Bool)
    case trickWon
    case collectTrick
    case strokes(Int)
    case elimination
    case matchResult(won: Bool)
}

@MainActor
protocol TableEffects {
    func play(_ effect: TableEffect, sound: Bool, haptics: Bool)
    func stop()
}

enum TableSound: String, CaseIterable, Sendable {
    case deal = "card-dealt"
    case place = "card-placed"
    case knock = "table-knock"
    case collect = "trick-collected"
    case score = "stroke-added"
    case result = "match-result"

    func url(in bundle: Bundle = .main) -> URL? {
        // Xcode may flatten synchronized resource folders when copying them.
        bundle.url(forResource: rawValue, withExtension: "wav")
            ?? bundle.url(forResource: rawValue, withExtension: "wav", subdirectory: "Sounds")
    }
}

enum TableHaptic: Equatable {
    enum Impact: Equatable { case soft, light, medium, rigid }
    case impact(Impact, intensity: CGFloat)
    case success
}

/// A narrow output boundary keeps preference and routing tests silent, without
/// creating an audio session or depending on haptic hardware in the simulator.
@MainActor
protocol TableEffectOutput {
    func play(_ sound: TableSound)
    func play(_ haptic: TableHaptic)
    func stop()
}

@MainActor
final class NativeTableEffects: TableEffects {
    private let output: any TableEffectOutput

    init() { output = DeviceTableEffectOutput() }
    init(output: any TableEffectOutput) { self.output = output }

    func play(_ effect: TableEffect, sound: Bool, haptics: Bool) {
        let cue: TableSound?
        let touch: TableHaptic?
        switch effect {
        case .deal:
            cue = .deal
            touch = nil
        case .cardPlaced:
            cue = .place
            touch = .impact(.soft, intensity: 0.18)
        case .knockTap(let human):
            cue = .knock
            touch = .impact(.rigid, intensity: human ? 0.65 : 0.40)
        case .trickWon:
            cue = nil
            touch = .impact(.light, intensity: 0.25)
        case .collectTrick:
            cue = .collect
            touch = nil
        case .strokes(let count):
            guard count > 0 else { return }
            cue = .score
            // A large penalty receives more weight, never a long vibration.
            touch = .impact(.medium, intensity: 0.30 + CGFloat(min(count, 4)) * 0.10)
        case .elimination:
            cue = nil
            touch = .impact(.rigid, intensity: 0.55)
        case .matchResult(let won):
            cue = .result
            touch = won ? .success : .impact(.soft, intensity: 0.40)
        }
        if sound, let cue { output.play(cue) }
        if haptics, let touch { output.play(touch) }
    }

    func stop() { output.stop() }
}

@MainActor
struct SilentTableEffects: TableEffects {
    func play(_ effect: TableEffect, sound: Bool, haptics: Bool) {}
    func stop() {}
}

@MainActor
private final class DeviceTableEffectOutput: TableEffectOutput {
    private var players: [TableSound: AVAudioPlayer] = [:]
    private var sessionConfigured = false
    private var sessionActive = false
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let notification = UINotificationFeedbackGenerator()
    private static let logger = Logger(subsystem: "com.DerFerdi.Tuppen", category: "TableEffects")

    func play(_ sound: TableSound) {
        do {
            let session = AVAudioSession.sharedInstance()
            if !sessionConfigured {
                // Ambient respects the silent switch and mixes with the user's
                // music. Game feedback must never take over other audio.
                try session.setCategory(.ambient, mode: .default)
                sessionConfigured = true
            }
            try session.setActive(true)
            sessionActive = true
            let player: AVAudioPlayer
            if let existing = players[sound] {
                player = existing
            } else {
                guard let url = sound.url() else {
                    Self.logger.error("Missing bundled table sound: \(sound.rawValue, privacy: .public)")
                    return
                }
                player = try AVAudioPlayer(contentsOf: url)
                player.volume = 0.65
                players[sound] = player
            }
            player.currentTime = 0
            player.play()
        } catch {
            // Device interruptions and unavailable audio never interrupt play.
            Self.logger.debug("Table sound unavailable: \(String(describing: error), privacy: .public)")
        }
    }

    func play(_ haptic: TableHaptic) {
        switch haptic {
        case .impact(let style, let intensity):
            let generator: UIImpactFeedbackGenerator
            switch style {
            case .soft: generator = soft
            case .light: generator = light
            case .medium: generator = medium
            case .rigid: generator = rigid
            }
            generator.impactOccurred(intensity: intensity)
        case .success:
            notification.notificationOccurred(.success)
        }
    }

    func stop() {
        for player in players.values {
            player.stop()
            player.currentTime = 0
        }
        // No delayed cues live here, so cancellation cannot emit a second knock
        // or replay stale audio when the app becomes active again.
        if sessionActive {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            sessionActive = false
        }
    }
}
