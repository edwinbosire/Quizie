import Foundation
import SwiftData

nonisolated enum QuestionDifficulty: String, Codable, CaseIterable, Sendable {
    case easy
    case medium
    case hard
}

nonisolated struct ConceptEvidenceWeight: Codable, Hashable, Sendable {
    let conceptID: String
    let weight: Double

    init(conceptID: String, weight: Double) {
        self.conceptID = conceptID
        self.weight = min(max(weight.isFinite ? weight : 0, 0), 1)
    }
}

nonisolated enum EvidenceSource: String, Codable, CaseIterable, Sendable {
    case mockExam
    case practiceQuestion
    case flashcard
}

nonisolated struct QuestionAttemptSnapshot: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let questionID: String
    let examAttemptID: UUID?
    let conceptWeights: [ConceptEvidenceWeight]
    let selectedAnswerIDs: [String]
    let correctAnswerIDs: [String]
    let wasCorrect: Bool
    let difficulty: QuestionDifficulty
    let responseTime: TimeInterval?
    let answeredAt: Date
    let source: EvidenceSource

    init(id: UUID = UUID(), questionID: String, examAttemptID: UUID?, conceptWeights: [ConceptEvidenceWeight], selectedAnswerIDs: [String], correctAnswerIDs: [String], wasCorrect: Bool, difficulty: QuestionDifficulty = .medium, responseTime: TimeInterval?, answeredAt: Date, source: EvidenceSource) {
        self.id = id
        self.questionID = questionID
        self.examAttemptID = examAttemptID
        self.conceptWeights = conceptWeights
        self.selectedAnswerIDs = selectedAnswerIDs
        self.correctAnswerIDs = correctAnswerIDs
        self.wasCorrect = wasCorrect
        self.difficulty = difficulty
        self.responseTime = responseTime.map { max(0, $0) }
        self.answeredAt = answeredAt
        self.source = source == .flashcard ? .practiceQuestion : source
    }
}

nonisolated struct FlashcardReviewEventSnapshot: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let flashcardID: String
    let conceptIDs: [String]
    let rating: FlashcardRating
    let reviewedAt: Date

    init(id: UUID = UUID(), flashcardID: String, conceptIDs: [String], rating: FlashcardRating, reviewedAt: Date) {
        self.id = id
        self.flashcardID = flashcardID
        self.conceptIDs = Array(Set(conceptIDs)).sorted()
        self.rating = rating
        self.reviewedAt = reviewedAt
    }
}

nonisolated struct LearningExamAttemptSnapshot: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let startedAt: Date
    var completedAt: Date?
    var questionAttemptIDs: [UUID]
    var correctCount: Int
    let totalCount: Int
    var passed: Bool?
    var duration: TimeInterval?
    var didTimeOut: Bool
    let testID: String?

    var isCompleted: Bool { completedAt != nil }
}

@Model
final class QuestionAttemptRecord {
    @Attribute(.unique) var id: UUID
    var questionID: String
    var examAttemptID: UUID?
    var conceptIDs: [String]
    var conceptWeightValues: [Double]
    var selectedAnswerIDs: [String]
    var correctAnswerIDs: [String]
    var wasCorrect: Bool
    var difficultyRawValue: String
    var responseTime: TimeInterval?
    var answeredAt: Date
    var sourceRawValue: String

    init(_ value: QuestionAttemptSnapshot) {
        id = value.id
        questionID = value.questionID
        examAttemptID = value.examAttemptID
        conceptIDs = value.conceptWeights.map(\.conceptID)
        conceptWeightValues = value.conceptWeights.map(\.weight)
        selectedAnswerIDs = value.selectedAnswerIDs
        correctAnswerIDs = value.correctAnswerIDs
        wasCorrect = value.wasCorrect
        difficultyRawValue = value.difficulty.rawValue
        responseTime = value.responseTime
        answeredAt = value.answeredAt
        sourceRawValue = value.source.rawValue
    }

    var snapshot: QuestionAttemptSnapshot {
        let weights = conceptIDs.enumerated().map { ConceptEvidenceWeight(conceptID: $0.element, weight: conceptWeightValues.indices.contains($0.offset) ? conceptWeightValues[$0.offset] : 1) }
        return QuestionAttemptSnapshot(id: id, questionID: questionID, examAttemptID: examAttemptID, conceptWeights: weights, selectedAnswerIDs: selectedAnswerIDs, correctAnswerIDs: correctAnswerIDs, wasCorrect: wasCorrect, difficulty: QuestionDifficulty(rawValue: difficultyRawValue) ?? .medium, responseTime: responseTime, answeredAt: answeredAt, source: EvidenceSource(rawValue: sourceRawValue) ?? .practiceQuestion)
    }
}

@Model
final class FlashcardReviewEventRecord {
    @Attribute(.unique) var id: UUID
    var flashcardID: String
    var conceptIDs: [String]
    var ratingRawValue: String
    var reviewedAt: Date

    init(_ value: FlashcardReviewEventSnapshot) {
        id = value.id
        flashcardID = value.flashcardID
        conceptIDs = value.conceptIDs
        ratingRawValue = value.rating.rawValue
        reviewedAt = value.reviewedAt
    }

    var snapshot: FlashcardReviewEventSnapshot {
        FlashcardReviewEventSnapshot(id: id, flashcardID: flashcardID, conceptIDs: conceptIDs, rating: FlashcardRating(rawValue: ratingRawValue) ?? .learning, reviewedAt: reviewedAt)
    }
}

@Model
final class LearningExamAttemptRecord {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var completedAt: Date?
    var questionAttemptIDs: [UUID]
    var correctCount: Int
    var totalCount: Int
    var passed: Bool?
    var duration: TimeInterval?
    var didTimeOut: Bool
    var testID: String?

    init(_ value: LearningExamAttemptSnapshot) {
        id = value.id
        startedAt = value.startedAt
        completedAt = value.completedAt
        questionAttemptIDs = value.questionAttemptIDs
        correctCount = value.correctCount
        totalCount = value.totalCount
        passed = value.passed
        duration = value.duration
        didTimeOut = value.didTimeOut
        testID = value.testID
    }

    func apply(_ value: LearningExamAttemptSnapshot) {
        completedAt = value.completedAt
        questionAttemptIDs = value.questionAttemptIDs
        correctCount = value.correctCount
        passed = value.passed
        duration = value.duration
        didTimeOut = value.didTimeOut
    }

    var snapshot: LearningExamAttemptSnapshot {
        LearningExamAttemptSnapshot(id: id, startedAt: startedAt, completedAt: completedAt, questionAttemptIDs: questionAttemptIDs, correctCount: correctCount, totalCount: totalCount, passed: passed, duration: duration, didTimeOut: didTimeOut, testID: testID)
    }
}
