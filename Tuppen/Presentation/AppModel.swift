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
    var path: [AppScreen] = []
    var sceneIsActive = true
    private(set) var snapshot: SessionUpdate?
    private(set) var isBusy = false
    private(set) var hasLoaded = false
    private(set) var failure: AppFailure?
    private(set) var automaticWorkFailed = false

    private let driver: SessionDriver
    @ObservationIgnored private var retryCommand: Command?
    private static let logger = Logger(subsystem: "com.DerFerdi.Tuppen", category: "Session")

    private enum Command {
        case load, newMatch, submit(GameAction), nextRound, resume, reset
    }

    init(driver: SessionDriver = SessionDriver()) { self.driver = driver }

    var view: PlayerView? { snapshot?.view }
    var statistics: LocalStatistics { snapshot?.statistics ?? LocalStatistics() }
    var hasActiveMatch: Bool { view?.matchPhase == .playing }

    func load() async {
        guard !hasLoaded else { return }
        await perform(.load)
    }

    func newMatch() async { await perform(.newMatch) }
    func submit(_ action: GameAction) async { await perform(.submit(action)) }
    func nextRound() async { await perform(.nextRound) }
    func resume() async {
        guard hasLoaded, snapshot != nil, path.last == .game else { return }
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
        defer { isBusy = false }
        do {
            switch command {
            case .load:
                snapshot = try await driver.load()
                hasLoaded = true
            case .newMatch:
                snapshot = try await driver.newMatch()
                path = [.game]
            case .submit(let action): snapshot = try await driver.submit(action)
            case .nextRound: snapshot = try await driver.nextRound()
            case .reset: snapshot = try await driver.resetStatistics()
            case .resume: break
            }
        } catch {
            if case .load = command { hasLoaded = true }
            report(error, command: command)
            return
        }
        if case .reset = command { return }
        do {
            // One loop owns automatic progression. Navigation, backgrounding,
            // and cancellation stop before the next transaction. An in-flight
            // successful save is still published so the display stays current.
            while path.last == .game, sceneIsActive, !Task.isCancelled {
                guard let next = try await driver.advance() else { break }
                snapshot = next
                await Task.yield()
            }
        } catch {
            // Earlier steps have committed. Retry automatic work, never resubmit
            // the human action that may have started this sequence.
            report(error, command: .resume)
        }
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
