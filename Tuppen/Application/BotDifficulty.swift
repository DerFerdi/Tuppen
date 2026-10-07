/// One strategy for every computer seat in a match. Raw values are part of the
/// save format; localized labels belong to presentation.
enum BotDifficulty: String, Codable, CaseIterable, Sendable {
    case easy, medium, hard

    func makeStrategy() -> any BotStrategy {
        switch self {
        case .easy: EasyBotStrategy()
        case .medium: V1BotStrategy()
        case .hard: HardBotStrategy()
        }
    }
}
