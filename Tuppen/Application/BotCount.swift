/// Supported local match configurations. The shipping New Game path keeps the
/// historical two-opponent default until player selection is available.
enum BotCount: Int, CaseIterable, Codable, Sendable {
    case one = 1
    case two = 2
    case three = 3

    var playerCount: Int { rawValue + 1 }
}
