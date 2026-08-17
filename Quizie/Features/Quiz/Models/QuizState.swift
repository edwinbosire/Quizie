import Foundation

enum QuizPhase: Equatable {
    case lobby
    case question(index: Int)
    case results
    case streakResult

    var id: String {
        switch self {
        case .lobby: return "lobby"
        case .question(let index): return "q\(index)"
        case .results: return "results"
        case .streakResult: return "streak-result"
        }
    }
}

enum QuizTransition: Equatable {
    case none
    case submitAfter(TimeInterval)
    case advanceAfter(TimeInterval)
    case endStreakAfter(TimeInterval)
    case streakEnded(Int)
    case completed(CompletedExam)
}

struct CompletedExam: Equatable {
    let sessionID: UUID
    let testID: String?
    let attemptDate: Date
    let score: Int
    let totalQuestions: Int
    let passed: Bool
    let elapsedSeconds: Int
    let didTimeOut: Bool
}

/// The quiz domain state machine. It has no UI, timer, or persistence dependencies.
struct QuizState {
    private(set) var phase: QuizPhase = .lobby
    private(set) var session: ExamSession?
    private(set) var selectedIndices: Set<Int> = []
    private(set) var timeRemaining: Int
    private(set) var didTimeOut = false
    private(set) var hasSubmittedAnswer = false
    private(set) var isCurrentAnswerCorrect = false

    let configuration: QuizConfiguration

    init(configuration: QuizConfiguration = .practice) {
        self.configuration = configuration
        self.timeRemaining = configuration.timeLimitSeconds
    }

    var currentIndex: Int {
        guard case .question(let index) = phase else { return 0 }
        return index
    }

    var currentQuestion: QuizQuestion? {
        session?.questions[safe: currentIndex]
    }

    var totalQuestions: Int { session?.questions.count ?? 0 }

    var mode: QuizMode { session?.mode ?? .practice }

    var progressFraction: Double {
        guard totalQuestions > 0 else { return 0 }
        return Double(currentIndex) / Double(totalQuestions)
    }

    var canSubmit: Bool {
        guard let question = currentQuestion, !hasSubmittedAnswer else { return false }
        return question.isMultiSelect
            ? selectedIndices.count == question.correctIndices.count
            : !selectedIndices.isEmpty
    }

    mutating func start(questions: [QuizQuestion], testID: String?, mode: QuizMode = .practice, sessionConfiguration: QuizConfiguration? = nil, at date: Date) {
        let activeConfiguration = sessionConfiguration ?? configuration
        session = ExamSession(
            testID: testID,
            mode: mode,
            configuration: activeConfiguration,
            questions: questions,
            startedAt: date
        )
        selectedIndices = []
        timeRemaining = activeConfiguration.timeLimitSeconds
        didTimeOut = false
        hasSubmittedAnswer = false
        isCurrentAnswerCorrect = false
        phase = questions.isEmpty ? .lobby : .question(index: 0)
    }

    mutating func toggleChoice(_ index: Int) -> QuizTransition {
        guard !hasSubmittedAnswer, let question = currentQuestion else { return .none }
        guard question.choices.indices.contains(index) else { return .none }

        if question.isMultiSelect {
            if selectedIndices.contains(index) {
                selectedIndices.remove(index)
            } else {
                selectedIndices.insert(index)
            }
        } else {
            selectedIndices = [index]
        }

        return canSubmit ? .submitAfter(0.3) : .none
    }

    mutating func submitCurrentAnswer() -> QuizTransition {
        guard canSubmit, var session, let question = currentQuestion else { return .none }

        let isCorrect = selectedIndices == question.correctIndices
        session.submit(answer: selectedIndices, for: question)
        self.session = session
        isCurrentAnswerCorrect = isCorrect
        hasSubmittedAnswer = true

        if isCorrect {
            return .advanceAfter(2)
        }
        return mode == .streak ? .endStreakAfter(1.5) : .none
    }

    mutating func advance(at date: Date) -> QuizTransition {
        guard case .question = phase, hasSubmittedAnswer else { return .none }

        let nextIndex = currentIndex + 1
        selectedIndices = []
        hasSubmittedAnswer = false
        isCurrentAnswerCorrect = false

        if nextIndex >= totalQuestions {
            if mode == .streak {
                return endStreak(at: date)
            }
            return finish(at: date, timedOut: false)
        }

        phase = .question(index: nextIndex)
        return .none
    }

    mutating func tick(at date: Date) -> QuizTransition {
        guard case .question = phase, mode != .streak else { return .none }

        if timeRemaining > 1 {
            timeRemaining -= 1
            return .none
        }

        timeRemaining = 0
        return finish(at: date, timedOut: true)
    }

    mutating func finish(at date: Date, timedOut: Bool) -> QuizTransition {
        guard phase != .results, phase != .streakResult, var session, session.finishedAt == nil else { return .none }

        session.finishedAt = date
        self.session = session
        didTimeOut = timedOut
        phase = .results

        return .completed(CompletedExam(
            sessionID: session.id,
            testID: session.testID,
            attemptDate: date,
            score: session.score,
            totalQuestions: session.questions.count,
            passed: session.passed,
            elapsedSeconds: max(0, Int(date.timeIntervalSince(session.startedAt))),
            didTimeOut: timedOut
        ))
    }

    mutating func endStreak(at date: Date) -> QuizTransition {
        guard case .question = phase, mode == .streak, var session, session.finishedAt == nil else { return .none }
        session.finishedAt = date
        self.session = session
        phase = .streakResult
        return .streakEnded(session.score)
    }

    mutating func acknowledgeTimeout() {
        didTimeOut = false
    }

    mutating func returnToLobby() {
        phase = .lobby
        session = nil
        selectedIndices = []
        hasSubmittedAnswer = false
        isCurrentAnswerCorrect = false
        didTimeOut = false
        timeRemaining = configuration.timeLimitSeconds
    }

    mutating func setPreview(
        session: ExamSession,
        phase: QuizPhase,
        selectedIndices: Set<Int> = [],
        timeRemaining: Int? = nil
    ) {
        self.session = session
        self.phase = phase
        self.selectedIndices = selectedIndices
        self.timeRemaining = timeRemaining ?? configuration.timeLimitSeconds
    }
}
