import Foundation

/// A single selectable practice test entry shown in the Tests tab.
struct PracticeTest: Identifiable, Hashable {
    let id: String
    let number: Int
    let title: String
    let subtitle: String
    let configuration: QuizConfiguration
}

enum TestCatalog {
    static let count = 10
    static let configuration = QuizConfiguration.practice

    static let tests: [PracticeTest] = (1...count).map { i in
        PracticeTest(
            id: "test-\(i)",
            number: i,
            title: "Practice Test \(i)",
            subtitle: configuration.summaryLabel,
            configuration: configuration
        )
    }
}

/// Aggregated statistics for a specific practice test.
struct PracticeTestStats {
    let bestScore: Int
    let totalQuestions: Int
    let passed: Bool
    let attempts: Int
    let mostRecentDate: Date

    var bestPercentage: Double {
        guard totalQuestions > 0 else { return 0 }
        return Double(bestScore) / Double(totalQuestions) * 100
    }
}

extension Array where Element == ExamAttempt {
    /// Best attempt summary for a given testID, or nil if no attempts exist.
    func stats(for testID: String) -> PracticeTestStats? {
        let filtered = filter { $0.testID == testID }
        guard !filtered.isEmpty,
              let best = filtered.max(by: { $0.score < $1.score }),
              let recent = filtered.max(by: { $0.attemptDate < $1.attemptDate }) else {
            return nil
        }
        return PracticeTestStats(
            bestScore: best.score,
            totalQuestions: best.totalQuestions,
            passed: best.passed,
            attempts: filtered.count,
            mostRecentDate: recent.attemptDate
        )
    }
}
