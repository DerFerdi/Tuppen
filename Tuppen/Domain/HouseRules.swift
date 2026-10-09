/// Only the two supported elimination thresholds can enter a match configuration.
enum MaximumStrokes: Int, CaseIterable, Codable, Sendable {
    case seven = 7
    case ten = 10
}

/// Immutable rules chosen at match creation. Difficulty and seat count are
/// separate application choices and do not change any rule here.
struct HouseRules: Equatable, Codable, Sendable {
    let maximumStrokes: MaximumStrokes
    let poverty: Bool
    let consecutiveKnockRestriction: Bool
    let fourPictures: Bool
    let fourPicturesBluffing: Bool
    let eightCardRule: Bool

    static let standard = try! HouseRules()

    init(
        maximumStrokes: MaximumStrokes = .seven, poverty: Bool = false,
        consecutiveKnockRestriction: Bool = false, fourPictures: Bool = false,
        fourPicturesBluffing: Bool = false, eightCardRule: Bool = false
    ) throws {
        guard !fourPicturesBluffing || fourPictures else { throw GameError.invalidHouseRules }
        self.maximumStrokes = maximumStrokes
        self.poverty = poverty
        self.consecutiveKnockRestriction = consecutiveKnockRestriction
        self.fourPictures = fourPictures
        self.fourPicturesBluffing = fourPicturesBluffing
        self.eightCardRule = eightCardRule
    }

    private enum CodingKeys: CodingKey {
        case maximumStrokes, poverty, consecutiveKnockRestriction, fourPictures, fourPicturesBluffing, eightCardRule
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            maximumStrokes: container.decode(MaximumStrokes.self, forKey: .maximumStrokes),
            poverty: container.decode(Bool.self, forKey: .poverty),
            consecutiveKnockRestriction: container.decode(Bool.self, forKey: .consecutiveKnockRestriction),
            fourPictures: container.decode(Bool.self, forKey: .fourPictures),
            fourPicturesBluffing: container.decode(Bool.self, forKey: .fourPicturesBluffing),
            eightCardRule: container.decode(Bool.self, forKey: .eightCardRule)
        )
    }
}

extension Card {
    var isPicture: Bool { rank <= .ace }
}

extension Array where Element == Card {
    /// Pictures need not have different ranks; suits do not affect the claim.
    var isFourPictures: Bool { count == 4 && allSatisfy(\.isPicture) }
}
