import SwiftUI
import Combine
import SwiftData

// MARK: - Quiz Phase
enum QuizPhase {
    case lobby
    case question(index: Int)
    case results
}

// MARK: - Quiz Engine
@MainActor
class QuizEngine: ObservableObject {

    @Published var phase: QuizPhase = .lobby
    @Published var session: ExamSession?
    @Published var selectedIndices: Set<Int> = []
    @Published var timeRemaining: Int = ExamSession.timeLimitSeconds
    @Published var didTimeOut = false
    @Published var showAnswerFeedback = false   // brief flash after submitting
    @Published var hasSubmittedAnswer = false
    @Published var isCurrentAnswerCorrect = false

    private var timer: AnyCancellable?
    private var autoAdvanceTask: Task<Void, Never>?
    private let bank = QuestionBank.shared
    
    // SwiftData context for saving exam attempts
    var modelContext: ModelContext?

    // MARK: Start
    func startExam() {
        let questions = bank.generateExam()
        session = ExamSession(questions: questions)
        selectedIndices = []
        timeRemaining = ExamSession.timeLimitSeconds
        didTimeOut = false
        showAnswerFeedback = false
        hasSubmittedAnswer = false
        isCurrentAnswerCorrect = false
        autoAdvanceTask?.cancel()
        phase = .question(index: 0)
        startTimer()
    }

    // MARK: Timer
    private func startTimer() {
        timer?.cancel()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    if self.timeRemaining > 0 {
                        self.timeRemaining -= 1
                    } else {
                        self.didTimeOut = true
                        self.finishExam()
                    }
                }
            }
    }

    func stopTimer() {
        timer?.cancel()
    }

    // MARK: Navigation
    var currentIndex: Int {
        if case .question(let idx) = phase { return idx }
        return 0
    }

    var currentQuestion: QuizQuestion? {
        session?.questions[safe: currentIndex]
    }

    var totalQuestions: Int { session?.questions.count ?? 0 }

    var progressFraction: Double {
        guard totalQuestions > 0 else { return 0 }
        return Double(currentIndex) / Double(totalQuestions)
    }

    var formattedTime: String {
        let m = timeRemaining / 60
        let s = timeRemaining % 60
        return String(format: "%d:%02d", m, s)
    }

    var isTimeWarning: Bool { timeRemaining <= 5 * 60 }   // last 5 mins

    // MARK: Answer selection
    func toggleChoice(_ index: Int, isMultiSelect: Bool) {
        // Don't allow changes after submission
        guard !hasSubmittedAnswer else { return }
        
        if isMultiSelect {
            if selectedIndices.contains(index) {
                selectedIndices.remove(index)
            } else {
                selectedIndices.insert(index)
            }
            
            // Auto-submit when correct number of choices are selected
            if let q = currentQuestion, selectedIndices.count == q.correctIndices.count {
                // Small delay for better UX - let user see their final selection
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                    submitAndAdvance()
                }
            }
        } else {
            selectedIndices = [index]
            
            // Auto-submit immediately for single choice
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                submitAndAdvance()
            }
        }
    }

    var canSubmit: Bool {
        guard let q = currentQuestion else { return false }
        if q.isMultiSelect {
            return selectedIndices.count == q.correctIndices.count
        }
        return !selectedIndices.isEmpty
    }

    // MARK: Submit answer & advance
    func submitAndAdvance() {
        guard var s = session, let q = currentQuestion else { return }
        
        // Check if answer is correct
        let isCorrect = selectedIndices == q.correctIndices
        isCurrentAnswerCorrect = isCorrect
        hasSubmittedAnswer = true
        
        // Submit the answer
        s.submit(answer: selectedIndices, for: q)
        session = s

        // If correct, auto-advance after 2 seconds
        if isCorrect {
            autoAdvanceTask?.cancel()
            autoAdvanceTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                guard !Task.isCancelled else { return }
                self.advanceToNext()
            }
        }
        // If incorrect, wait for user to manually tap next
    }
    
    private func advanceToNext() {
        let nextIndex = currentIndex + 1
        selectedIndices = []
        hasSubmittedAnswer = false
        isCurrentAnswerCorrect = false
        autoAdvanceTask?.cancel()

        if nextIndex >= totalQuestions {
            finishExam()
        } else {
            phase = .question(index: nextIndex)
        }
    }
    
    // Manual advance (for incorrect answers)
    func manualAdvance() {
        advanceToNext()
    }

    // MARK: Finish
    func finishExam() {
        stopTimer()
        var s = session
        s?.finishedAt = Date()
        session = s
        
        // Save the exam attempt to SwiftData
        if let session = s, let context = modelContext {
            let attempt = ExamAttempt(from: session, didTimeOut: didTimeOut)
            context.insert(attempt)
            try? context.save()
        }
        
        phase = .results
    }

    // MARK: Restart
    func returnToLobby() {
        stopTimer()
        autoAdvanceTask?.cancel()
        phase = .lobby
        session = nil
    }
}

// MARK: - Safe array subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
