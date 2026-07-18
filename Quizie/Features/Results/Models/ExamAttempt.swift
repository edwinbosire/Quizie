import Foundation
import SwiftData

struct ExamAttemptSnapshot: Identifiable, Equatable {
    let id: UUID
    let attemptDate: Date
    let score: Int
    let totalQuestions: Int
    let passed: Bool
    let elapsedSeconds: Int
    let didTimeOut: Bool
    let testID: String?

    var percentage: Double { totalQuestions > 0 ? Double(score) / Double(totalQuestions) * 100 : 0 }
    var formattedElapsed: String { String(format: "%d:%02d", elapsedSeconds / 60, elapsedSeconds % 60) }
    var formattedAttemptedDate: String { RelativeDateTimeFormatter().localizedString(for: attemptDate, relativeTo: Date()) }
}

/// SwiftData model to persist exam attempt history
@Model
final class ExamAttempt {
    var id: UUID
    var attemptDate: Date
    var score: Int
    var totalQuestions: Int
    var passed: Bool
    var elapsedSeconds: Int
    var didTimeOut: Bool
    /// Identifier of the practice test taken (nil for ad-hoc random exams).
    var testID: String?
    
    /// Derived properties
    var percentage: Double {
        guard totalQuestions > 0 else { return 0 }
        return Double(score) / Double(totalQuestions) * 100
    }
    
    var formattedElapsed: String {
        let s = elapsedSeconds
        return String(format: "%d:%02d", s / 60, s % 60)
    }

	var formattedAttemptedDate: String {
		let formatter = RelativeDateTimeFormatter()
		formatter.unitsStyle = .full  // "1 hour ago"
		let string = formatter.localizedString(for: attemptDate, relativeTo: Date())
		return string
	}

	init(
        id: UUID = UUID(),
        attemptDate: Date = Date(),
        score: Int,
        totalQuestions: Int,
        passed: Bool,
        elapsedSeconds: Int,
        didTimeOut: Bool = false,
        testID: String? = nil
    ) {
        self.id = id
        self.attemptDate = attemptDate
        self.score = score
        self.totalQuestions = totalQuestions
        self.passed = passed
        self.elapsedSeconds = elapsedSeconds
        self.didTimeOut = didTimeOut
        self.testID = testID
    }
    
    /// Create an ExamAttempt from an ExamSession
    convenience init(from session: ExamSession, didTimeOut: Bool = false) {
        self.init(
            attemptDate: session.finishedAt ?? Date(),
            score: session.score,
            totalQuestions: session.questions.count,
            passed: session.passed,
            elapsedSeconds: session.elapsedSeconds,
            didTimeOut: didTimeOut,
            testID: session.testID
        )
    }

    convenience init(from exam: CompletedExam) {
        self.init(
            id: exam.sessionID,
            attemptDate: exam.attemptDate,
            score: exam.score,
            totalQuestions: exam.totalQuestions,
            passed: exam.passed,
            elapsedSeconds: exam.elapsedSeconds,
            didTimeOut: exam.didTimeOut,
            testID: exam.testID
        )
    }

    var snapshot: ExamAttemptSnapshot {
        ExamAttemptSnapshot(id: id, attemptDate: attemptDate, score: score, totalQuestions: totalQuestions, passed: passed, elapsedSeconds: elapsedSeconds, didTimeOut: didTimeOut, testID: testID)
    }
}

/// Extension to calculate performance statistics
extension Array where Element == ExamAttemptSnapshot {
    var averageScore: Double {
        guard !isEmpty else { return 0 }
        let total = reduce(0) { $0 + $1.score }
        return Double(total) / Double(count)
    }
    
    var averagePercentage: Double {
        guard !isEmpty else { return 0 }
        let total = reduce(0.0) { $0 + $1.percentage }
        return total / Double(count)
    }
    
    var passRate: Double {
        guard !isEmpty else { return 0 }
        let passCount = filter { $0.passed }.count
        return Double(passCount) / Double(count) * 100
    }
    
    var bestScore: Int {
        map { $0.score }.max() ?? 0
    }
    
    var recentAttempts: [ExamAttemptSnapshot] {
        sorted { $0.attemptDate > $1.attemptDate }
    }
}
