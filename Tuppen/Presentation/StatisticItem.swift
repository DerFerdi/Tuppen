import Foundation

/// The screen reads existing human counters; formatting never records events.
struct StatisticItem: Identifiable {
    let id: String
    let title: String.LocalizationValue
    let value: Int

    static func items(in statistics: LocalStatistics) -> [StatisticItem] {
        [
            StatisticItem(id: "matchesPlayed", title: "Matches Played", value: statistics.matchesPlayed),
            StatisticItem(id: "matchesWon", title: "Matches Won", value: statistics.matchesWon),
            StatisticItem(id: "roundsPlayed", title: "Rounds Played", value: statistics.roundsPlayed),
            StatisticItem(id: "roundsWon", title: "Rounds Won", value: statistics.roundsWon),
            StatisticItem(id: "knocksMade", title: "Knocks Made", value: statistics.knocksMade),
            StatisticItem(id: "knocksHeld", title: "Knocks Held", value: statistics.knocksHeld),
            StatisticItem(id: "knocksPassed", title: "Knocks Passed", value: statistics.knocksPassed),
            StatisticItem(id: "highestStakeReached", title: "Highest Stake Reached", value: statistics.highestStakeReached),
            StatisticItem(id: "eightCardRulesPlayed", title: "Eight-Card-Rules played", value: statistics.eightCardRulesPlayed),
            StatisticItem(id: "eightCardRulesWon", title: "Eight-Card-Rules won", value: statistics.eightCardRulesWon),
            StatisticItem(id: "fourPicturesExchanges", title: "Four Pictures exchanges", value: statistics.fourPicturesExchanges),
            StatisticItem(id: "fourPicturesBluffs", title: "Successful Four Pictures bluffs", value: statistics.fourPicturesBluffs)
        ]
    }
}
