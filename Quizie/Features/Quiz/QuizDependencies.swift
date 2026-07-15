import Combine
import Foundation

protocol QuizClock {
    var now: Date { get }
}

struct SystemQuizClock: QuizClock {
    var now: Date { Date() }
}

@MainActor
protocol ExamAttemptStore: AnyObject {
    func fetchAll() throws -> [ExamAttemptSnapshot]
    func save(_ exam: CompletedExam) throws
}

final class NoOpExamAttemptStore: ExamAttemptStore {
    func fetchAll() throws -> [ExamAttemptSnapshot] { [] }
    func save(_ exam: CompletedExam) throws {}
}

final class QuizCancellation {
    private var cancellation: (() -> Void)?

    init(_ cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }

    deinit { cancel() }
}

@MainActor
protocol QuizScheduler {
    func schedule(after delay: TimeInterval, action: @escaping @MainActor () -> Void) -> QuizCancellation
    func scheduleRepeating(every interval: TimeInterval, action: @escaping @MainActor () -> Void) -> QuizCancellation
}

@MainActor
final class SystemQuizScheduler: QuizScheduler {
    func schedule(after delay: TimeInterval, action: @escaping @MainActor () -> Void) -> QuizCancellation {
        let task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            action()
        }
        return QuizCancellation { task.cancel() }
    }

    func scheduleRepeating(every interval: TimeInterval, action: @escaping @MainActor () -> Void) -> QuizCancellation {
        let cancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { _ in action() }
        return QuizCancellation { cancellable.cancel() }
    }
}
