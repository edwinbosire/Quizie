import Foundation

@MainActor
enum StudyStatistics {
    static let flashcardsReviewedKey = "studyStatistics.flashcardsReviewed"
    static let flashcardsKnownKey = "studyStatistics.flashcardsKnown"
    static let matchRoundsKey = "studyStatistics.matchRounds"
    static let matchBestTimeKey = "studyStatistics.matchBestTime"
    static let longestStreakKey = "studyStatistics.longestStreak"

    static func longestStreak(defaults: UserDefaults = .standard) -> Int {
        defaults.integer(forKey: longestStreakKey)
    }

    @discardableResult
    static func recordStreak(_ streak: Int, defaults: UserDefaults = .standard) -> Int {
        let best = max(longestStreak(defaults: defaults), streak)
        defaults.set(best, forKey: longestStreakKey)
        return best
    }

    static func recordFlashcardChanges(
        from previous: [String: FlashcardRating],
        to current: [String: FlashcardRating],
        defaults: UserDefaults = .standard
    ) {
        var reviewed = defaults.integer(forKey: flashcardsReviewedKey)
        var known = defaults.integer(forKey: flashcardsKnownKey)

        for (cardID, rating) in current {
            let previousRating = previous[cardID]
            guard previousRating != rating else { continue }

            if previousRating == nil {
                reviewed += 1
            }

            if rating.isKnown && previousRating?.isKnown != true {
                known += 1
            } else if !rating.isKnown && previousRating?.isKnown == true {
                known = max(0, known - 1)
            }
        }

        defaults.set(reviewed, forKey: flashcardsReviewedKey)
        defaults.set(known, forKey: flashcardsKnownKey)
    }

    static func recordMatchRound(
        time: TimeInterval,
        defaults: UserDefaults = .standard
    ) {
        guard time > 0 else { return }

        let currentBest = defaults.double(forKey: matchBestTimeKey)
        if currentBest == 0 || time < currentBest {
            defaults.set(time, forKey: matchBestTimeKey)
        }

        defaults.set(
            defaults.integer(forKey: matchRoundsKey) + 1,
            forKey: matchRoundsKey
        )
    }
}
