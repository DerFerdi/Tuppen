import Foundation

/// Eight-card play reserves two rows for the entire tiebreak, even as cards
/// leave the hand. Four-card rows keep each exposed hit area usable in portrait.
struct HandLayout {
    let rows: Int
    let cardWidth: CGFloat
    let spacing: CGFloat

    init(width: CGFloat, height: CGFloat, eightCardRule: Bool) {
        rows = eightCardRule ? 2 : 1
        let rowHeight = (height - CGFloat(rows - 1) * 8) / CGFloat(rows)
        cardWidth = min(108, max(0, (rowHeight - 14) * 0.7))
        spacing = min(12, (width - 20 - cardWidth * 4) / 3)
    }

    static func height(available: CGFloat, eightCardRule: Bool) -> CGFloat {
        eightCardRule ? min(226, max(168, available * 0.34)) : min(174, max(104, available * 0.27))
    }
}
