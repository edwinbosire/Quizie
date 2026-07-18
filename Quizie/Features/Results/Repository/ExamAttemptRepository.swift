import SwiftData
import Observation
import Foundation

@MainActor
final class SwiftDataExamAttemptStore: ExamAttemptStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [ExamAttemptSnapshot] {
        let descriptor = FetchDescriptor<ExamAttempt>(sortBy: [SortDescriptor(\.attemptDate, order: .reverse)])
        return try context.fetch(descriptor).map(\.snapshot)
    }

    func save(_ exam: CompletedExam) throws {
        context.insert(ExamAttempt(from: exam))
        try context.save()
    }
}

@MainActor
final class InMemoryExamAttemptStore: ExamAttemptStore {
    private var attempts: [ExamAttemptSnapshot]
    init(attempts: [ExamAttemptSnapshot] = []) { self.attempts = attempts }
    func fetchAll() throws -> [ExamAttemptSnapshot] { attempts.sorted { $0.attemptDate > $1.attemptDate } }
    func save(_ exam: CompletedExam) throws {
        attempts.append(ExamAttemptSnapshot(id: exam.sessionID, attemptDate: exam.attemptDate, score: exam.score, totalQuestions: exam.totalQuestions, passed: exam.passed, elapsedSeconds: exam.elapsedSeconds, didTimeOut: exam.didTimeOut, testID: exam.testID))
    }
}

@MainActor
@Observable
final class AttemptHistory: ExamAttemptStore {
    private let store: any ExamAttemptStore
    private let issues: PersistenceIssueCenter
    private(set) var attempts: [ExamAttemptSnapshot] = []
    init(store: any ExamAttemptStore, issues: PersistenceIssueCenter) { self.store = store; self.issues = issues; reload() }
    func fetchAll() throws -> [ExamAttemptSnapshot] { try store.fetchAll() }
    func reload() {
        do { attempts = try store.fetchAll() }
        catch { issues.report(error, operation: "Loading exam attempts") }
    }
    func save(_ exam: CompletedExam) throws {
        do { try store.save(exam); reload() }
        catch { issues.report(error, operation: "Saving exam attempt"); throw error }
    }
}
