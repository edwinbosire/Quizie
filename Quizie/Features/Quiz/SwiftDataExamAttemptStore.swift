import SwiftData

@MainActor
final class SwiftDataExamAttemptStore: ExamAttemptStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func save(_ exam: CompletedExam) throws {
        context.insert(ExamAttempt(from: exam))
        try context.save()
    }
}
