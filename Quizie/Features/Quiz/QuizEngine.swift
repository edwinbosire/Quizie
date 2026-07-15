import Combine
import Foundation

/// Observable adapter between the pure `QuizState` and UI/infrastructure concerns.
@MainActor
final class QuizEngine: ObservableObject {
    @Published private(set) var state: QuizState
    @Published private(set) var persistenceError: Error?
    @Published private(set) var contentError: ContentRepositoryError?

    private let questionRepository: any QuestionRepository
    private let clock: any QuizClock
    private let scheduler: any QuizScheduler
    private var attemptStore: any ExamAttemptStore
    private var timer: QuizCancellation?
    private var pendingSubmission: QuizCancellation?
    private var pendingAdvance: QuizCancellation?

    let configuration: QuizConfiguration

    init(
        configuration: QuizConfiguration = .practice,
        questionRepository: any QuestionRepository,
        attemptStore: (any ExamAttemptStore)? = nil,
        clock: (any QuizClock)? = nil,
        scheduler: (any QuizScheduler)? = nil
    ) {
        self.configuration = configuration
        self.state = QuizState(configuration: configuration)
        self.questionRepository = questionRepository
        self.attemptStore = attemptStore ?? NoOpExamAttemptStore()
        self.clock = clock ?? SystemQuizClock()
        self.scheduler = scheduler ?? SystemQuizScheduler()
    }

    var phase: QuizPhase { state.phase }
    var session: ExamSession? { state.session }
    var selectedIndices: Set<Int> { state.selectedIndices }
    var timeRemaining: Int { state.timeRemaining }
    var didTimeOut: Bool { state.didTimeOut }
    var hasSubmittedAnswer: Bool { state.hasSubmittedAnswer }
    var isCurrentAnswerCorrect: Bool { state.isCurrentAnswerCorrect }
    var currentIndex: Int { state.currentIndex }
    var currentQuestion: QuizQuestion? { state.currentQuestion }
    var totalQuestions: Int { state.totalQuestions }
    var progressFraction: Double { state.progressFraction }
    var canSubmit: Bool { state.canSubmit }

    var formattedTime: String {
        String(format: "%d:%02d", timeRemaining / 60, timeRemaining % 60)
    }

    var isTimeWarning: Bool { timeRemaining <= 5 * 60 }

    func installAttemptStore(_ store: any ExamAttemptStore) {
        attemptStore = store
    }

    func startExam(testID: String? = nil) {
        cancelScheduledWork()
        let questions: [QuizQuestion]
        do {
            questions = try questionRepository.questions(count: configuration.questionCount, seed: testID)
            contentError = nil
        } catch let repositoryError as ContentRepositoryError {
            contentError = repositoryError
            return
        } catch {
            contentError = .invalidContent(name: "questions", reason: error.localizedDescription)
            return
        }
        state.start(questions: questions, testID: testID, at: clock.now)
        persistenceError = nil

        guard case .question = state.phase else { return }
        timer = scheduler.scheduleRepeating(every: 1) { [weak self] in
            self?.handleTick()
        }
    }

    func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    func toggleChoice(_ index: Int, isMultiSelect: Bool) {
        pendingSubmission?.cancel()
        handle(state.toggleChoice(index))
    }

    func submitAndAdvance() {
        pendingSubmission?.cancel()
        pendingSubmission = nil
        handle(state.submitCurrentAnswer())
    }

    func manualAdvance() {
        pendingAdvance?.cancel()
        pendingAdvance = nil
        handle(state.advance(at: clock.now))
    }

    func finishExam() {
        handle(state.finish(at: clock.now, timedOut: false))
    }

    func acknowledgeTimeout() {
        state.acknowledgeTimeout()
    }

    func dismissContentError() {
        contentError = nil
    }

    func returnToLobby() {
        cancelScheduledWork()
        state.returnToLobby()
        persistenceError = nil
    }

    private func handleTick() {
        handle(state.tick(at: clock.now))
    }

    private func handle(_ transition: QuizTransition) {
        switch transition {
        case .none:
            break

        case .submitAfter(let delay):
            pendingSubmission = scheduler.schedule(after: delay) { [weak self] in
                self?.submitAndAdvance()
            }

        case .advanceAfter(let delay):
            pendingAdvance?.cancel()
            pendingAdvance = scheduler.schedule(after: delay) { [weak self] in
                self?.manualAdvance()
            }

        case .completed(let exam):
            cancelScheduledWork()
            do {
                try attemptStore.save(exam)
            } catch {
                persistenceError = error
            }
        }
    }

    private func cancelScheduledWork() {
        timer?.cancel()
        pendingSubmission?.cancel()
        pendingAdvance?.cancel()
        timer = nil
        pendingSubmission = nil
        pendingAdvance = nil
    }

    func setPreviewState(
        session: ExamSession,
        phase: QuizPhase,
        selectedIndices: Set<Int> = [],
        timeRemaining: Int? = nil
    ) {
        state.setPreview(
            session: session,
            phase: phase,
            selectedIndices: selectedIndices,
            timeRemaining: timeRemaining
        )
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
