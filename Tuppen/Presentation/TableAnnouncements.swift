import UIKit

@MainActor
protocol TableAnnouncements {
    func announce(_ message: String, locale: Locale) async throws
    func stop()
}

/// Only one beat is spoken at a time. Waiting for completion keeps bot actions
/// aligned with speech instead of building a queue behind the visible game.
@MainActor
final class NativeTableAnnouncements: NSObject, TableAnnouncements {
    private let center: NotificationCenter
    private let isEnabled: () -> Bool
    private let post: (NSAttributedString) -> Void
    private let clock: any TableClock
    private var pending: (id: UUID, message: String, continuation: CheckedContinuation<Void, Error>)?
    private var timeout: Task<Void, Never>?

    init(
        center: NotificationCenter = .default,
        clock: any TableClock = ContinuousTableClock(),
        isEnabled: @escaping () -> Bool = { UIAccessibility.isVoiceOverRunning },
        post: @escaping (NSAttributedString) -> Void = { UIAccessibility.post(notification: .announcement, argument: $0) }
    ) {
        self.center = center
        self.clock = clock
        self.isEnabled = isEnabled
        self.post = post
    }

    func announce(_ message: String, locale: Locale) async throws {
        try Task.checkCancellation()
        guard isEnabled() else { return }
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                pending = (id, message, continuation)
                center.addObserver(self, selector: #selector(didFinish(_:)),
                                   name: UIAccessibility.announcementDidFinishNotification, object: nil)
                timeout = Task { [weak self, clock] in
                    do {
                        try await clock.wait(for: TablePacing.announcementTimeout)
                        self?.finish(id: id)
                    } catch { return }
                }
                let value = NSAttributedString(string: message, attributes: [
                    .accessibilitySpeechLanguage: locale.identifier,
                    .accessibilitySpeechAnnouncementPriority: UIAccessibilityPriority.low.rawValue
                ])
                post(value)
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.finish(id: id, cancelled: true) }
        }
    }

    func stop() {
        if let pending { finish(id: pending.id) }
    }

    @objc private func didFinish(_ notification: Notification) {
        guard let pending,
              notification.userInfo?[UIAccessibility.announcementStringValueUserInfoKey] as? String == pending.message else { return }
        // Interrupted speech also completes this beat. Never fight a user's
        // focus gesture by repeatedly announcing the same event.
        finish(id: pending.id)
    }

    private func finish(id: UUID, cancelled: Bool = false) {
        guard let pending, pending.id == id else { return }
        self.pending = nil
        center.removeObserver(self, name: UIAccessibility.announcementDidFinishNotification, object: nil)
        timeout?.cancel()
        timeout = nil
        if cancelled { pending.continuation.resume(throwing: CancellationError()) }
        else { pending.continuation.resume() }
    }
}
