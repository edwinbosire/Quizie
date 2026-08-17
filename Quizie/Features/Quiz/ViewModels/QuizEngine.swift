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
    @ObservationIgnored private var learningEvents: LearningEventHistory?
    @ObservationIgnored private var timer: QuizCancellation?
    @ObservationIgnored private var pendingSubmission: QuizCancellation?
    @ObservationIgnored private var pendingAdvance: QuizCancellation?
    @ObservationIgnored private let statisticsDefaults: UserDefaults
    @ObservationIgnored private var learningExam: LearningExamAttemptSnapshot?
    @ObservationIgnored private var questionStartedAt: Date?
    @ObservationIgnored private var activeEvidenceSource: EvidenceSource = .mockExam
    @ObservationIgnored private var activeTargetConceptIDs: [String]?
    @ObservationIgnored private var activeTargetQuestionCount: Int?

    let configuration: QuizConfiguration

    init(
        configuration: QuizConfiguration = .practice,
        questionRepository: any QuestionRepository,
        attemptStore: (any ExamAttemptStore)? = nil,
        learningEvents: LearningEventHistory? = nil,
        clock: (any QuizClock)? = nil,
        scheduler: (any QuizScheduler)? = nil,
        statisticsDefaults: UserDefaults = .standard
    ) {
        self.configuration = configuration
        self.state = QuizState(configuration: configuration)
        self.questionRepository = questionRepository
        self.attemptStore = attemptStore ?? NoOpExamAttemptStore()
        self.learningEvents = learningEvents
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
    var hasAnsweredCurrentQuestion: Bool {
        guard let currentQuestion else { return false }
        return session?.answers[currentQuestion.id] != nil
    }
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
        start(mode: .exam, testID: testID, source: .mockExam)
    }

    func startStreak() {
        start(mode: .streak, testID: nil, source: .practiceQuestion)
    }

    func startTargetedPractice(conceptID: String, questionCount: Int = 6) {
        startTargetedPractice(conceptIDs: [conceptID], questionCount: questionCount)
    }

    func startTargetedPractice(conceptIDs: [String], questionCount: Int = 6) {
        start(mode: .practice, testID: nil, source: .practiceQuestion, conceptIDs: conceptIDs, questionCount: questionCount)
    }

    func restartCurrentMode() {
        if let activeTargetConceptIDs {
            startTargetedPractice(conceptIDs: activeTargetConceptIDs, questionCount: activeTargetQuestionCount ?? 6)
        } else if isStreakMode {
            startStreak()
        } else {
            startExam(testID: session?.testID)
        }
    }

    private func start(mode: QuizMode, testID: String?, source: EvidenceSource, conceptIDs: [String]? = nil, questionCount: Int? = nil) {
        abandonActiveLearningExam()
        cancelScheduledWork()
        let questions: [QuizQuestion]
        do {
            let requestedCount = questionCount ?? (mode == .streak ? Int.max : configuration.questionCount)
            if let conceptIDs {
                let requestedConceptIDs = Set(conceptIDs)
                questions = Array(try questionRepository.questions(count: Int.max, seed: "concept-\(conceptIDs.sorted().joined(separator: "-"))").filter { !requestedConceptIDs.isDisjoint(with: $0.taxonomy.conceptIds) }.prefix(requestedCount))
            } else {
                questions = try questionRepository.questions(count: requestedCount, seed: testID)
            }
            if conceptIDs != nil, questions.isEmpty {
                contentError = .invalidContent(name: "questions", reason: "No questions are mapped to this topic yet.")
                return
            }
            contentError = nil
        } catch let repositoryError as ContentRepositoryError {
            contentError = repositoryError
            return
        } catch {
            contentError = .invalidContent(name: "questions", reason: error.localizedDescription)
            return
        }
        let targetedConfiguration = conceptIDs == nil ? nil : QuizConfiguration.custom(questionCount: questions.count, timeLimitSeconds: max(5 * 60, questions.count * 90), passMarkCount: max(1, Int(ceil(Double(questions.count) * 0.75))))
        state.start(questions: questions, testID: testID, mode: mode, sessionConfiguration: targetedConfiguration, at: clock.now)
        activeEvidenceSource = source
        activeTargetConceptIDs = conceptIDs
        activeTargetQuestionCount = questionCount
        persistenceError = nil
        questionStartedAt = clock.now
        if mode != .streak, let session = state.session {
            let exam = LearningExamAttemptSnapshot(id: session.id, startedAt: session.startedAt, completedAt: nil, questionAttemptIDs: [], correctCount: 0, totalCount: session.questions.count, passed: nil, duration: nil, didTimeOut: false, testID: testID)
            learningExam = exam
            learningEvents?.upsert(exam)
        }

        guard case .question = state.phase, mode != .streak else { return }
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
        let question = state.currentQuestion
        let selectedIndices = state.selectedIndices
        let answeredAt = clock.now
        let transition = state.submitCurrentAnswer()
        if state.hasSubmittedAnswer, let question {
            capture(question: question, selectedIndices: selectedIndices, answeredAt: answeredAt)
        }
        if state.mode == .streak, state.isCurrentAnswerCorrect {
            bestStreak = StudyStatistics.recordStreak(currentStreak, defaults: statisticsDefaults)
        }
        handle(transition)
    }

    func manualAdvance() {
        pendingAdvance?.cancel()
        pendingAdvance = nil
        let transition = state.advance(at: clock.now)
        if transition == .none, case .question = state.phase { questionStartedAt = clock.now }
        handle(transition)
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
        abandonActiveLearningExam()
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
            completeLearningExam(exam)
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

    private func capture(question: QuizQuestion, selectedIndices: Set<Int>, answeredAt: Date) {
        let conceptWeights = question.taxonomy.conceptIds.enumerated().map { index, conceptID in
            ConceptEvidenceWeight(conceptID: conceptID, weight: [1.0, 0.7, 0.3][safe: index] ?? 0.3)
        }
        let selectedAnswers = selectedIndices.sorted().compactMap { question.choices[safe: $0] }
        let correctAnswers = question.correctIndices.sorted().compactMap { question.choices[safe: $0] }
        let value = QuestionAttemptSnapshot(
            questionID: question.id,
            examAttemptID: learningExam?.id,
            conceptWeights: conceptWeights,
            selectedAnswerIDs: selectedAnswers,
            correctAnswerIDs: correctAnswers,
            wasCorrect: selectedIndices == question.correctIndices,
            responseTime: questionStartedAt.map { answeredAt.timeIntervalSince($0) },
            answeredAt: answeredAt,
            source: activeEvidenceSource
        )
        learningEvents?.append(value)
        if var exam = learningExam {
            exam.questionAttemptIDs.append(value.id)
            exam.correctCount += value.wasCorrect ? 1 : 0
            learningExam = exam
            learningEvents?.upsert(exam)
        }
    }

    private func completeLearningExam(_ completed: CompletedExam) {
        guard var exam = learningExam, exam.id == completed.sessionID else { return }
        exam.completedAt = completed.attemptDate
        exam.correctCount = completed.score
        exam.passed = completed.passed
        exam.duration = TimeInterval(completed.elapsedSeconds)
        exam.didTimeOut = completed.didTimeOut
        learningEvents?.upsert(exam)
        learningExam = nil
    }

    private func abandonActiveLearningExam() {
        guard let exam = learningExam, exam.completedAt == nil else { return }
        learningEvents?.upsert(exam)
        learningExam = nil
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
