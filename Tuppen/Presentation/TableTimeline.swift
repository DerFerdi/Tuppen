import Foundation

enum TableReaction: Equatable, Sendable {
    case knocked, held, passed, eliminated
}

/// A disposable rendering of public facts. The session is already saved before
/// these frames are shown; none of this timing or staging enters a checkpoint.
struct TablePresentation: Equatable, Sendable {
    var view: PlayerView
    var players: [PublicPlayerState]
    var trick: TrickState
    var hand: [Card]
    var stake: Int
    var highlightedWinner: PlayerID?
    var collecting = false
    var thinkingPlayer: PlayerID?
    var reactions: [PlayerID: TableReaction] = [:]
    var strokeChanges: [StrokeChange] = []
    var roundOutcome: RoundOutcome?
    var resultVisible = false
    var knockPulse = 0

    init(view: PlayerView) {
        self.view = view
        players = view.players
        trick = view.currentTrick
        hand = view.hand
        stake = view.stake
        if case .finished(let outcome) = view.roundPhase {
            roundOutcome = outcome
            resultVisible = true
        }
    }
}

enum TablePause: Equatable, Sendable {
    case thinking, responseThinking, cardMovement, cardSettle
    case knockGap, knockReveal, reaction, trickRead, trickWinner, collection
    case roundOutcome, scoring, elimination, result, spectatorRound, deal
}

enum TablePacing {
    static func motionDuration(reduceMotion: Bool) -> Double { reduceMotion ? 0.12 : 0.3 }

    static func duration(_ pause: TablePause, reduceMotion: Bool) -> Duration {
        let seconds: Double
        switch pause {
        case .thinking: seconds = reduceMotion ? 0.25 : 0.5
        case .responseThinking: seconds = reduceMotion ? 0.35 : 0.65
        case .cardMovement: seconds = motionDuration(reduceMotion: reduceMotion)
        case .cardSettle: seconds = 0.18
        case .knockGap: seconds = 0.14
        case .knockReveal: seconds = 0.4
        case .reaction: seconds = 0.8
        case .trickRead: seconds = 0.3
        case .trickWinner: seconds = 0.8
        case .collection: seconds = motionDuration(reduceMotion: reduceMotion)
        case .roundOutcome: seconds = 0.8
        case .scoring: seconds = 0.65
        case .elimination: seconds = 0.8
        case .result: seconds = 0.5
        case .spectatorRound: seconds = 1.8
        case .deal: seconds = reduceMotion ? 0.08 : 0.16
        }
        return .seconds(seconds)
    }
}

protocol TableClock: Sendable {
    func wait(for duration: Duration) async throws
}

struct ContinuousTableClock: TableClock {
    func wait(for duration: Duration) async throws { try await Task.sleep(for: duration) }
}

struct TableBeat: Equatable, Sendable {
    let frame: TablePresentation
    let pause: TablePause?
    var effect: TableEffect?
}

/// Converts one accepted transaction into a short, ordered visual sequence.
/// Winners and penalties come from engine events, never from card comparisons.
enum TableTimeline {
    static func beats(for update: SessionUpdate, after previous: TablePresentation?) -> [TableBeat] {
        guard let view = update.view, !update.events.isEmpty else { return [] }
        var frame = TablePresentation(view: view)
        frame.resultVisible = false
        frame.roundOutcome = nil
        let startsRound = update.events.contains { if case .roundStarted = $0 { true } else { false } }
        // Replacing a match can start another round numbered one. Its deal must
        // not inherit a previous match's visible stake or Knock pulse.
        if !startsRound, let previous, previous.view.roundNumber == view.roundNumber {
            frame.players = previous.players
            frame.stake = previous.stake
            frame.knockPulse = previous.knockPulse
        }
        var beats: [TableBeat] = []
        for event in update.events {
            switch event {
            case .roundStarted:
                frame.hand = []
                frame.players = view.players.map { replacing($0, count: 0) }
                beats.append(TableBeat(frame: frame, pause: .deal))
                for count in 1...4 {
                    frame.hand = Array(view.hand.prefix(count))
                    frame.players = view.players.map { replacing($0, count: min(count, $0.remainingCardCount)) }
                    beats.append(TableBeat(frame: frame, pause: .deal, effect: .deal))
                }
            case .cardPlayed(let play):
                // The engine has already cleared an early completed trick. Keep
                // its recorded public cards on the table until collection ends.
                if let completed = completedTrick(in: update) { frame.trick = completed.trick }
                updatePlayer(play.player, in: &frame, from: view, cardCount: true)
                beats.append(TableBeat(frame: frame, pause: .cardMovement, effect: .cardPlaced))
                beats.append(TableBeat(frame: frame, pause: .cardSettle))
            case .playerKnocked(let player, let stake):
                frame.reactions[player] = .knocked
                for _ in 0..<2 {
                    frame.knockPulse += 1
                    beats.append(TableBeat(frame: frame, pause: .knockGap, effect: .knockTap(human: player == view.player)))
                }
                frame.stake = stake
                beats.append(TableBeat(frame: frame, pause: .knockReveal))
            case .playerHeld(let player):
                frame.reactions[player] = .held
                beats.append(TableBeat(frame: frame, pause: .reaction))
            case .playerPassed(let player):
                frame.reactions[player] = .passed
                updatePlayer(player, in: &frame, from: view, participation: true)
                beats.append(TableBeat(frame: frame, pause: .reaction))
            case .trickWon(_, let winner):
                if let completed = completedTrick(in: update) { frame.trick = completed.trick }
                beats.append(TableBeat(frame: frame, pause: .trickRead))
                frame.highlightedWinner = winner
                beats.append(TableBeat(frame: frame, pause: .trickWinner, effect: .trickWon))
                frame.collecting = true
                beats.append(TableBeat(frame: frame, pause: .collection, effect: .collectTrick))
                frame.trick = TrickState(number: view.currentTrick.number)
                frame.collecting = false
                frame.highlightedWinner = nil
            case .roundEnded(let outcome):
                frame.roundOutcome = outcome
                beats.append(TableBeat(frame: frame, pause: .roundOutcome))
            case .strokesAdded(let player, let amount):
                updatePlayer(player, in: &frame, from: view, strokes: true)
                frame.strokeChanges.append(StrokeChange(player: player, amount: amount))
                beats.append(TableBeat(frame: frame, pause: .scoring, effect: .strokes(amount)))
            case .playerEliminated(let player):
                updatePlayer(player, in: &frame, from: view, status: true)
                frame.reactions[player] = .eliminated
                beats.append(TableBeat(frame: frame, pause: .elimination, effect: .elimination))
            case .matchWon(let winner):
                frame.resultVisible = true
                beats.append(TableBeat(frame: frame, pause: .result, effect: .matchResult(won: winner == view.player)))
            case .matchDrawn:
                frame.resultVisible = true
                beats.append(TableBeat(frame: frame, pause: .result, effect: .matchResult(won: false)))
            }
        }
        frame.players = view.players
        frame.stake = view.stake
        frame.reactions = [:]
        frame.strokeChanges = []
        if case .finished = view.roundPhase { frame.resultVisible = true }
        // The final frame has no delay/effect of its own. The caller settles to
        // it after the last beat; no historical event is replayed on resume.
        beats.append(TableBeat(frame: frame, pause: nil))
        return beats
    }

    private static func completedTrick(in update: SessionUpdate) -> CompletedTrick? {
        for event in update.events {
            if case .trickWon(let number, _) = event {
                return update.view?.completedTricks.first { $0.trick.number == number }
            }
        }
        return nil
    }

    private static func updatePlayer(
        _ player: PlayerID, in frame: inout TablePresentation, from view: PlayerView,
        cardCount: Bool = false, participation: Bool = false, strokes: Bool = false, status: Bool = false
    ) {
        guard let index = frame.players.firstIndex(where: { $0.id == player }),
              let latest = view.players.first(where: { $0.id == player }) else { return }
        let old = frame.players[index]
        frame.players[index] = PublicPlayerState(
            id: player, strokes: strokes ? latest.strokes : old.strokes,
            status: status ? latest.status : old.status,
            isParticipating: participation ? latest.isParticipating : old.isParticipating,
            remainingCardCount: cardCount ? latest.remainingCardCount : old.remainingCardCount
        )
    }

    private static func replacing(_ player: PublicPlayerState, count: Int) -> PublicPlayerState {
        PublicPlayerState(id: player.id, strokes: player.strokes, status: player.status,
                          isParticipating: player.isParticipating, remainingCardCount: count)
    }
}
