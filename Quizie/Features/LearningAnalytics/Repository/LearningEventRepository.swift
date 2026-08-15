import Foundation
import Observation
import SwiftData

@MainActor
protocol LearningEventStore: AnyObject {
    func fetchQuestionAttempts() throws -> [QuestionAttemptSnapshot]
    func fetchFlashcardReviews() throws -> [FlashcardReviewEventSnapshot]
    func fetchExamAttempts() throws -> [LearningExamAttemptSnapshot]
    func append(_ attempt: QuestionAttemptSnapshot) throws
    func append(_ review: FlashcardReviewEventSnapshot) throws
    func upsert(_ exam: LearningExamAttemptSnapshot) throws
}

@MainActor
final class SwiftDataLearningEventStore: LearningEventStore {
    private let context: ModelContext

    init(context: ModelContext) { self.context = context }

    func fetchQuestionAttempts() throws -> [QuestionAttemptSnapshot] {
        let descriptor = FetchDescriptor<QuestionAttemptRecord>(sortBy: [SortDescriptor(\.answeredAt)])
        return try context.fetch(descriptor).map(\.snapshot)
    }

    func fetchFlashcardReviews() throws -> [FlashcardReviewEventSnapshot] {
        let descriptor = FetchDescriptor<FlashcardReviewEventRecord>(sortBy: [SortDescriptor(\.reviewedAt)])
        return try context.fetch(descriptor).map(\.snapshot)
    }

    func fetchExamAttempts() throws -> [LearningExamAttemptSnapshot] {
        let descriptor = FetchDescriptor<LearningExamAttemptRecord>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        return try context.fetch(descriptor).map(\.snapshot)
    }

    func append(_ attempt: QuestionAttemptSnapshot) throws {
        let id = attempt.id
        guard try context.fetch(FetchDescriptor<QuestionAttemptRecord>(predicate: #Predicate { $0.id == id })).isEmpty else { return }
        context.insert(QuestionAttemptRecord(attempt))
        try context.save()
    }

    func append(_ review: FlashcardReviewEventSnapshot) throws {
        let id = review.id
        guard try context.fetch(FetchDescriptor<FlashcardReviewEventRecord>(predicate: #Predicate { $0.id == id })).isEmpty else { return }
        context.insert(FlashcardReviewEventRecord(review))
        try context.save()
    }

    func upsert(_ exam: LearningExamAttemptSnapshot) throws {
        let id = exam.id
        let descriptor = FetchDescriptor<LearningExamAttemptRecord>(predicate: #Predicate { $0.id == id })
        if let record = try context.fetch(descriptor).first { record.apply(exam) }
        else { context.insert(LearningExamAttemptRecord(exam)) }
        try context.save()
    }
}

@MainActor
final class InMemoryLearningEventStore: LearningEventStore {
    private var questions: [UUID: QuestionAttemptSnapshot]
    private var flashcards: [UUID: FlashcardReviewEventSnapshot]
    private var exams: [UUID: LearningExamAttemptSnapshot]

    init(questionAttempts: [QuestionAttemptSnapshot] = [], flashcardReviews: [FlashcardReviewEventSnapshot] = [], examAttempts: [LearningExamAttemptSnapshot] = []) {
        questions = Dictionary(uniqueKeysWithValues: questionAttempts.map { ($0.id, $0) })
        flashcards = Dictionary(uniqueKeysWithValues: flashcardReviews.map { ($0.id, $0) })
        exams = Dictionary(uniqueKeysWithValues: examAttempts.map { ($0.id, $0) })
    }

    func fetchQuestionAttempts() throws -> [QuestionAttemptSnapshot] { questions.values.sorted { $0.answeredAt < $1.answeredAt } }
    func fetchFlashcardReviews() throws -> [FlashcardReviewEventSnapshot] { flashcards.values.sorted { $0.reviewedAt < $1.reviewedAt } }
    func fetchExamAttempts() throws -> [LearningExamAttemptSnapshot] { exams.values.sorted { $0.startedAt > $1.startedAt } }
    func append(_ attempt: QuestionAttemptSnapshot) throws { questions[attempt.id] = questions[attempt.id] ?? attempt }
    func append(_ review: FlashcardReviewEventSnapshot) throws { flashcards[review.id] = flashcards[review.id] ?? review }
    func upsert(_ exam: LearningExamAttemptSnapshot) throws { exams[exam.id] = exam }
}

@MainActor
@Observable
final class LearningEventHistory {
    private let store: any LearningEventStore
    private let issues: PersistenceIssueCenter
    private(set) var questionAttempts: [QuestionAttemptSnapshot] = []
    private(set) var flashcardReviews: [FlashcardReviewEventSnapshot] = []
    private(set) var examAttempts: [LearningExamAttemptSnapshot] = []
    private(set) var revision = 0

    init(store: any LearningEventStore, issues: PersistenceIssueCenter) {
        self.store = store
        self.issues = issues
        reload()
    }

    func append(_ value: QuestionAttemptSnapshot) {
        do {
            try store.append(value)
            guard !questionAttempts.contains(where: { $0.id == value.id }) else { return }
            questionAttempts.append(value)
            questionAttempts.sort { $0.answeredAt < $1.answeredAt }
            revision += 1
        }
        catch { issues.report(error, operation: "Saving question evidence") }
    }

    func append(_ value: FlashcardReviewEventSnapshot) {
        do {
            try store.append(value)
            guard !flashcardReviews.contains(where: { $0.id == value.id }) else { return }
            flashcardReviews.append(value)
            flashcardReviews.sort { $0.reviewedAt < $1.reviewedAt }
            revision += 1
        }
        catch { issues.report(error, operation: "Saving flashcard evidence") }
    }

    func upsert(_ value: LearningExamAttemptSnapshot) {
        do {
            try store.upsert(value)
            if let index = examAttempts.firstIndex(where: { $0.id == value.id }) { examAttempts[index] = value }
            else { examAttempts.append(value) }
            examAttempts.sort { $0.startedAt > $1.startedAt }
            revision += 1
        }
        catch { issues.report(error, operation: "Saving learning exam") }
    }

    func reload() {
        do {
            questionAttempts = try store.fetchQuestionAttempts()
            flashcardReviews = try store.fetchFlashcardReviews()
            examAttempts = try store.fetchExamAttempts()
            revision += 1
        } catch {
            issues.report(error, operation: "Loading learning history")
        }
    }

    func importLegacyExamAttempts(_ values: [ExamAttemptSnapshot]) {
        for value in values where !examAttempts.contains(where: { $0.id == value.id }) {
            upsert(LearningExamAttemptSnapshot(id: value.id, startedAt: value.attemptDate.addingTimeInterval(-TimeInterval(value.elapsedSeconds)), completedAt: value.attemptDate, questionAttemptIDs: [], correctCount: value.score, totalCount: value.totalQuestions, passed: value.passed, duration: TimeInterval(value.elapsedSeconds), didTimeOut: value.didTimeOut, testID: value.testID))
        }
    }
}
