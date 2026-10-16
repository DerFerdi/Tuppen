import Foundation

/// Version 1 accumulated additive fields before House Rules established a new
/// format boundary. Fill only those historically absent keys, then let the same
/// typed decoder and engine replay validate both formats. Explicit nulls and
/// malformed values must survive this step so decoding can reject them.
enum VersionOneMigration {
    static func apply(to data: Data) throws -> Data {
        guard var envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              var game = envelope["game"] as? [String: Any] else {
            throw PersistenceError.corruptData
        }
        if var statistics = game["statistics"] as? [String: Any] {
            for key in ["eightCardRulesPlayed", "eightCardRulesWon", "fourPicturesExchanges", "fourPicturesBluffs"] {
                if statistics[key] == nil { statistics[key] = 0 }
            }
            game["statistics"] = statistics
        }
        if var session = game["session"] as? [String: Any] {
            if session["botCount"] == nil { session["botCount"] = 2 }
            if session["difficulty"] == nil { session["difficulty"] = "medium" }
            if var match = session["match"] as? [String: Any] {
                if match["houseRules"] == nil {
                    match["houseRules"] = try JSONSerialization.jsonObject(
                        with: JSONEncoder().encode(HouseRules.standard)
                    )
                }
                match["players"] = playersAddingStrokeMaximum(match["players"])
                if var round = match["round"] as? [String: Any] {
                    for key in ["poorParticipants", "povertyResponses", "removedHands", "revealedHands"] {
                        if round[key] == nil { round[key] = [] as [Any] }
                    }
                    if var history = round["history"] as? [String: Any] {
                        history["initialPlayers"] = playersAddingStrokeMaximum(history["initialPlayers"])
                        round["history"] = history
                    }
                    match["round"] = round
                }
                session["match"] = match
            }
            game["session"] = session
        }
        envelope["game"] = game
        return try JSONSerialization.data(withJSONObject: envelope)
    }

    private static func playersAddingStrokeMaximum(_ value: Any?) -> Any? {
        guard let players = value as? [[String: Any]] else { return value }
        return players.map { player in
            var player = player
            if player["maximumStrokes"] == nil { player["maximumStrokes"] = 7 }
            return player
        }
    }
}
