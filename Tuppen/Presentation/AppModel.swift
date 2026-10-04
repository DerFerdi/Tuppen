import Foundation
import Observation
import OSLog

enum AppScreen: Hashable {
    case game, statistics, settings
}

enum AppFailure: Equatable {
    case restore, save, reset
}

/// Main-actor state is presentation only. The actor-owned driver performs each
/// disk transaction and returns restricted, immutable data for rendering.
@MainActor @Observable
final class AppModel {
    var path: [AppScreen] = [] {
        didSet { if path.last != .game { cancelPresentation() } }
    }
    var sceneIsActive = true {
        didSet { if !sceneIsActive { cancelPresentation() } }
    }
    var reduceMotion = false
    var soundEnabled = true
    var hapticsEnabled = true
    private(set) var snapshot: SessionUpdate?
    private(set) var table: TablePresentation?
    private(set) var isBusy = false
    private(set) var hasLoaded = false
    private(set) var failure: AppFailure?
    private(set) var automaticWorkFailed = false

    private let driver: SessionDriver
    private let clock: any TableClock
    private let effects: any TableEffects
    @ObservationIgnored private var retryCommand: Command?
    @ObservationIgnored private var work: Task<Void, Never>?
    private static let logger = Logger(subsystem: "com.DerFerdi.Tuppen", category: "Session")

    private enum Command {
        case load, newMatch, submit(GameAction), nextRound, resume, reset
    }

    init(
        driver: SessionDriver = SessionDriver(), clock: any TableClock = ContinuousTableClock(),
        effects: any TableEffects = NativeTableEffects()
    ) {
        self.driver = driver
        self.clock = clock
        self.effects = effects
    }

    var view: PlayerView? { snapshot?.view }
    var statistics: LocalStatistics { snapshot?.statistics ?? LocalStatistics() }
    var hasActiveMatch: Bool { view?.matchPhase == .playing }
    var canKnock: Bool { canSubmit(.knock) }

    func canSubmit(_ action: GameAction) -> Bool {
        !isBusy && view?.legalActions.contains(action) == true
    }

    func load() async {
        guard !hasLoaded else { return }
        await perform(.load)
    }

    func newMatch() async { await perform(.newMatch) }
    func submit(_ action: GameAction) async {
        guard canSubmit(action) else { return }
        await perform(.submit(action))
    }
    func nextRound() async { await perform(.nextRound) }
    func resume() async {
        // A quick foreground/navigation return can race the cancelled task's
        // cleanup. Wait for its one in-flight transaction before resuming.
        if let work {
            guard work.isCancelled else { return }
            await work.value
        }
        guard hasLoaded, snapshot != nil, path.last == .game,
              failure == nil, !automaticWorkFailed else { return }
        await perform(.resume)
    }
    func resetStatistics() async { await perform(.reset) }
    func dismissFailure() { failure = nil }

    func retry() async {
        guard let retryCommand else { return }
        await perform(retryCommand)
    }

    private func perform(_ command: Command) async {
        guard !isBusy else { return }
        isBusy = true
        failure = nil
        automaticWorkFailed = false
        let task = Task {
            await run(command)
            work = nil
            isBusy = false
        }
        work = task
        await task.value
    }

    private func run(_ command: Command) async {
        var retry = command
        do {
            switch command {
            case .load:
                snapshot = try await driver.load()
                hasLoaded = true
                settle()
            case .newMatch:
                let update = try await driver.newMatch()
                path = [.game]
                retry = .resume
                try await present(update)
            case .submit(let action):
                let update = try await driver.submit(action)
                retry = .resume
                try await present(update)
            case .nextRound:
                let update = try await driver.nextRound()
                retry = .resume
                try await present(update)
            case .reset:
                snapshot = try await driver.resetStatistics()
                settle()
                return
            case .resume: break
            }
            retry = .resume
            while canPresent, !Task.isCancelled, let view {
                if case .finished = view.roundPhase {
                    // An eliminated spectator has no meaningful round decision.
                    // Keep the result readable, then finish the remaining match.
                    guard view.matchPhase == .playing,
                          view.players.first(where: { $0.id == view.player })?.status == .eliminated else { break }
                    try await pause(.spectatorRound)
                    try await present(driver.nextRound())
                    continue
                }
                let player: PlayerID?
                let delay: TablePause
                switch view.roundPhase {
                case .playing(let turn): player = turn.player; delay = .thinking
                case .awaitingResponses(let pending): player = pending.expectedResponder; delay = .responseThinking
                case .finished: player = nil; delay = .thinking
                }
                guard let player, player != view.player else { break }
                table?.thinkingPlayer = player
                try await pause(delay)
                guard let update = try await driver.advance() else { break }
                try await present(update)
            }
        } catch is CancellationError {
            // Cancellation discards choreography, never the committed state.
            // Resume starts from that checkpoint and cannot repeat its effects.
            settle()
        } catch {
            if case .load = command { hasLoaded = true }
            settle()
            report(error, command: retry)
        }
    }

    private var canPresent: Bool { path.last == .game && sceneIsActive }

    private func present(_ update: SessionUpdate) async throws {
        // Publish authority immediately after the save, then reveal its public
        // consequences. Controls remain gated until the whole sequence settles.
        snapshot = update
        guard canPresent, !Task.isCancelled else { settle(); return }
        let beats = TableTimeline.beats(for: update, after: table)
        if beats.isEmpty { settle(); return }
        for beat in beats {
            try Task.checkCancellation()
            guard canPresent else { throw CancellationError() }
            table = beat.frame
            if let effect = beat.effect { effects.play(effect, sound: soundEnabled, haptics: hapticsEnabled) }
            if let delay = beat.pause { try await pause(delay) }
        }
    }

    private func pause(_ delay: TablePause) async throws {
        try Task.checkCancellation()
        guard canPresent else { throw CancellationError() }
        try await clock.wait(for: TablePacing.duration(delay, reduceMotion: reduceMotion))
        try Task.checkCancellation()
        guard canPresent else { throw CancellationError() }
    }

    private func settle() {
        table = view.map(TablePresentation.init)
    }

    private func cancelPresentation() {
        work?.cancel()
        effects.stop()
        settle()
    }

    private func report(_ error: Error, command: Command) {
        retryCommand = command
        if case .resume = command { automaticWorkFailed = true }
        switch command {
        case .load: failure = .restore
        case .reset: failure = .reset
        default: failure = .save
        }
        #if DEBUG
        Self.logger.error("Session operation failed: \(String(describing: error), privacy: .public)")
        #endif
    }
}
