/// SplitMix64 provides a small, reproducible stream whose state can be saved.
/// Deck and decision streams must be seeded independently: a bot never receives
/// the random state used to deal hidden cards.
struct SeededRandom: RandomNumberGenerator, Codable, Equatable, Sendable {
    private(set) var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
