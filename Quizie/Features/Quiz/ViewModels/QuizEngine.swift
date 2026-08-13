import Foundation
import Observation

/// Observable adapter between the pure `QuizState` and UI/infrastructure concerns.
@MainActor
@Observable
final class QuizEngine {
    private(set) var state: QuizState
    private(set) var persistenceError: Error?
    private(set) var contentError: ContentRepositoryError?
    private(set) var bestStreak: Int

    private let questionRepository: any QuestionRepository
    private let clock: any QuizClock
    private let scheduler: any QuizScheduler
    @ObservationIgnored private var attemptStore: any ExamAttemptStore
    @ObservationIgnored private var timer: QuizCancellation?
    @ObservationIgnored private var pendingSubmission: QuizCancellation?
    @ObservationIgnored private var pendingAdvance: QuizCancellation?
    @ObservationIgnored private let statisticsDefaults: UserDefaults

    let configuration: QuizConfiguration

    init(
        configuration: QuizConfiguration = .practice,
        questionRepository: any QuestionRepository,
        attemptStore: (any ExamAttemptStore)? = nil,
        clock: (any QuizClock)? = nil,
        scheduler: (any QuizScheduler)? = nil,
        statisticsDefaults: UserDefaults = .standard
    ) {
        self.configuration = configuration
        self.state = QuizState(configuration: configuration)
        self.questionRepository = questionRepository
        self.attemptStore = attemptStore ?? NoOpExamAttemptStore()
        self.clock = clock ?? SystemQuizClock()
        self.scheduler = scheduler ?? SystemQuizScheduler()
        self.statisticsDefaults = statisticsDefaults
        self.bestStreak = StudyStatistics.longestStreak(defaults: statisticsDefaults)
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
    var mode: QuizMode { state.mode }
    var isStreakMode: Bool { mode == .streak }
    var currentStreak: Int { session?.score ?? 0 }

    var formattedTime: String {
        String(format: "%d:%02d", timeRemaining / 60, timeRemaining % 60)
    }

    var isTimeWarning: Bool { timeRemaining <= 5 * 60 }

    func installAttemptStore(_ store: any ExamAttemptStore) {
        attemptStore = store
    }

    func startExam(testID: String? = nil) {
        start(mode: .practice, testID: testID)
    }

    func startStreak() {
        start(mode: .streak, testID: nil)
    }

    func restartCurrentMode() {
        if isStreakMode {
            startStreak()
        } else {
            startExam(testID: session?.testID)
        }
    }

    private func start(mode: QuizMode, testID: String?) {
        cancelScheduledWork()
        let questions: [QuizQuestion]
        do {
            let questionCount = mode == .streak ? Int.max : configuration.questionCount
            questions = try questionRepository.questions(count: questionCount, seed: testID)
            contentError = nil
        } catch let repositoryError as ContentRepositoryError {
            contentError = repositoryError
            return
        } catch {
            contentError = .invalidContent(name: "questions", reason: error.localizedDescription)
            return
        }
        state.start(questions: questions, testID: testID, mode: mode, at: clock.now)
        persistenceError = nil

        guard case .question = state.phase, mode == .practice else { return }
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
        let transition = state.submitCurrentAnswer()
        if state.mode == .streak, state.isCurrentAnswerCorrect {
            bestStreak = StudyStatistics.recordStreak(currentStreak, defaults: statisticsDefaults)
        }
        handle(transition)
    }

    func manualAdvance() {
        pendingAdvance?.cancel()
        pendingAdvance = nil
        handle(state.advance(at: clock.now))
    }

    func finishExam() {
        handle(state.finish(at: clock.now, timedOut: false))
    }

    func endStreak() {
        handle(state.endStreak(at: clock.now))
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

        case .endStreakAfter(let delay):
            pendingAdvance?.cancel()
            pendingAdvance = scheduler.schedule(after: delay) { [weak self] in
                self?.endStreak()
            }

        case .streakEnded(let streak):
            cancelScheduledWork()
            bestStreak = StudyStatistics.recordStreak(streak, defaults: statisticsDefaults)

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
