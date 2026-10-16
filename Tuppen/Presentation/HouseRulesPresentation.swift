import Foundation

/// Shared copy for setup, saved match information, and the optional tutorial.
/// Configuration validity continues to belong to HouseRules.
enum HouseRuleOption: CaseIterable, Identifiable {
    case poverty, consecutiveKnockRestriction, fourPictures, bluffing, eightCardRule

    var id: Self { self }
    var title: String.LocalizationValue {
        switch self {
        case .poverty: "Poverty"
        case .consecutiveKnockRestriction: "Consecutive Knock Restriction"
        case .fourPictures: "Four Pictures"
        case .bluffing: "Bluffing"
        case .eightCardRule: "Eight-Card-Rule"
        }
    }
    var explanation: String.LocalizationValue {
        switch self {
        case .poverty:
            "Starting a round one stroke before elimination makes you poor. The stake is two: poor players stay in; others Hold or Pass. No Knock or Four Pictures in this round."
        case .consecutiveKnockRestriction:
            "The last player to Knock cannot Knock again until another player has Knocked."
        case .fourPictures:
            "On your turn, before your first card and your own Knock, exchange four picture cards for four new cards. Jack, Queen, King, and Ace count, including repeated ranks. You may exchange again while eligible."
        case .bluffing:
            "Players may falsely claim Four Pictures. Others can challenge before replacement cards are dealt. A false claimant or an unsuccessful challenger receives one stroke."
        case .eightCardRule:
            "If the final remaining players would all be eliminated together, they play an eight-card tiebreak. Eight cards, eight tricks: only the eighth decides the match."
        }
    }
    func isEnabled(in rules: HouseRules) -> Bool {
        switch self {
        case .poverty: rules.poverty
        case .consecutiveKnockRestriction: rules.consecutiveKnockRestriction
        case .fourPictures: rules.fourPictures
        case .bluffing: rules.fourPicturesBluffing
        case .eightCardRule: rules.eightCardRule
        }
    }
}

extension AppModel {
    func selectMaximumStrokes(_ maximum: MaximumStrokes) {
        updateHouseRules(maximum: maximum)
    }

    func selectHouseRule(_ option: HouseRuleOption, enabled: Bool) {
        updateHouseRules(option: option, enabled: enabled)
    }

    private func updateHouseRules(maximum: MaximumStrokes? = nil, option: HouseRuleOption? = nil, enabled: Bool = false) {
        let old = newMatchHouseRules
        let pictures = option == .fourPictures ? enabled : old.fourPictures
        // Turning off the parent clears its dependent selection. The domain
        // initializer still validates every configuration produced by the form.
        guard let rules = try? HouseRules(
            maximumStrokes: maximum ?? old.maximumStrokes,
            poverty: option == .poverty ? enabled : old.poverty,
            consecutiveKnockRestriction: option == .consecutiveKnockRestriction ? enabled : old.consecutiveKnockRestriction,
            fourPictures: pictures,
            fourPicturesBluffing: pictures && (option == .bluffing ? enabled : old.fourPicturesBluffing),
            eightCardRule: option == .eightCardRule ? enabled : old.eightCardRule
        ) else { return }
        newMatchHouseRules = rules
    }
}

extension GameStrings {
    static var maximumStrokesExplanation: String.LocalizationValue {
        "Choose seven or ten strokes. Reaching the chosen limit eliminates a player."
    }

    func trickHeading(number: Int, in view: PlayerView) -> String {
        if view.isEightCardRule {
            return number == 8 ? text("Eight-Card-Rule · Decisive eighth trick")
                : text("Eight-Card-Rule · Trick \(number) of 8")
        }
        if !view.poorParticipants.isEmpty { return text("Poverty · Stake: \(view.stake)") }
        return text("Trick \(number)")
    }

    func challengePrompt(in view: PlayerView) -> String {
        guard case .awaitingFourPicturesChallenges(let pending) = view.roundPhase else { return "" }
        return announcement(.fourPicturesClaimed(pending.claimant), in: view)
    }
}
