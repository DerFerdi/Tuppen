import Foundation

/// Stable presentation positions derived from the public table order. Passed
/// and eliminated seats stay in place so committed cards never change owners.
struct TableSeating: Equatable, Sendable {
    let human: PlayerID
    let opponents: [PlayerID]

    init(view: PlayerView) {
        human = view.player
        let seats = view.players.map(\.id)
        if let index = seats.firstIndex(of: human) {
            opponents = (1..<seats.count).map { seats[(index + $0) % seats.count] }
        } else {
            opponents = []
        }
    }

    func cardWidth(in size: CGSize) -> CGFloat {
        // Keep the original three-seat composition. Centered one-opponent and
        // three-opponent rows need a clear vertical gap above the human's card.
        min(88, min(size.width * 0.24, size.height * (opponents.count == 2 ? 0.43 : 0.30)))
    }

    func position(for player: PlayerID, in size: CGSize) -> CGPoint? {
        if player == human {
            return CGPoint(x: size.width * 0.5, y: size.height * (opponents.count == 2 ? 0.67 : 0.75))
        }
        guard let index = opponents.firstIndex(of: player) else { return nil }
        let x: CGFloat
        switch opponents.count {
        case 1: x = 0.5
        case 2: x = index == 0 ? 0.30 : 0.70
        case 3: x = 0.18 + CGFloat(index) * 0.32
        default: return nil
        }
        return CGPoint(x: size.width * x, y: size.height * (opponents.count == 2 ? 0.34 : 0.25))
    }

    func angle(for player: PlayerID) -> Double {
        if player == human { return 2 }
        guard let index = opponents.firstIndex(of: player) else { return 0 }
        if opponents.count == 1 { return 0 }
        if index == 0 { return -5 }
        return index == opponents.count - 1 ? 5 : 0
    }
}
