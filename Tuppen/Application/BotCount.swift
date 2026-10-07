/// Supported local match configurations. Two opponents remain the default
/// selection for each new match.
enum BotCount: Int, CaseIterable, Codable, Sendable {
    case one = 1
    case two = 2
    case three = 3

    var playerCount: Int { rawValue + 1 }
}
