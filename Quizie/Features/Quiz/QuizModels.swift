import Foundation
import Observation

// MARK: - Raw JSON model (matches questions.json exactly)
struct RawQuestion: Codable {
    let question_id: String
    let book_section_id: String
    let category: String
    let question: String
    let year: String
    let choices: [String]
    let correct: [String]
    let explanation: RawExplanation
}

struct RawExplanation: Codable {
    let link: String
}

struct RawQuestionsFile: Codable {
    let data: [RawQuestion]
}

// MARK: - App Question Model
struct QuizQuestion: Identifiable {
    let id: String
    let question: String
    let choices: [String]
    let correctIndices: Set<Int>       // indices into choices[]
    let isMultiSelect: Bool
    let year: String
    let category: Int
    let explanationLink: String

    var correctChoices: [String] {
        choices.enumerated()
            .filter { correctIndices.contains($0.offset) }
            .map { $0.element }
    }
}

// MARK: - User Answer
struct UserAnswer {
    let questionID: String
    let selectedIndices: Set<Int>
    let isCorrect: Bool
}

// MARK: - Exam Session
struct ExamSession: Identifiable {
    let id = UUID()
    var testID: String? = nil
    let questions: [QuizQuestion]
    var answers: [String: UserAnswer] = [:]   // keyed by question ID
    var startedAt: Date = Date()
    var finishedAt: Date?

    static let questionCount = 24
    static let timeLimitSeconds = 45 * 60     // 45 minutes
    static let passMarkCount   = 18

    var score: Int {
        answers.values.filter { $0.isCorrect }.count
    }

    var passed: Bool {
        score >= ExamSession.passMarkCount
    }

    var answeredCount: Int { answers.count }

    var elapsedSeconds: Int {
        Int(( finishedAt ?? Date() ).timeIntervalSince(startedAt))
    }

    var formattedElapsed: String {
        let s = elapsedSeconds
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    var percentage: Double {
        Double(score) / Double(questions.count) * 100
    }
}

// MARK: - Question Bank
@Observable
class QuestionBank {
    static let shared = QuestionBank()
    private(set) var allQuestions: [QuizQuestion] = []

    init() {
        load()
    }

    private func load() {
        guard let url = Bundle.main.url(forResource: "questions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode(RawQuestionsFile.self, from: data) else {
            // Fallback: try loading from app bundle path used in development
            loadFromPath()
            return
        }
        allQuestions = raw.data.map { QuizQuestion(from: $0) }
    }

    private func loadFromPath() {
        // Development fallback — look for the file next to the bundle
        let paths = [
            Bundle.main.bundlePath + "/questions.json",
            FileManager.default.currentDirectoryPath + "/questions.json"
        ]
        for path in paths {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
               let raw = try? JSONDecoder().decode(RawQuestionsFile.self, from: data) {
                allQuestions = raw.data.map { QuizQuestion(from: $0) }
                return
            }
        }
    }

    /// Returns a new shuffled exam of `count` questions, balanced across categories.
    /// If `seed` is provided, the same seed always produces the same questions in the same order.
    func generateExam(count: Int = ExamSession.questionCount, seed: String? = nil) -> [QuizQuestion] {
        guard !allQuestions.isEmpty else { return [] }
        if let seed {
            var rng = SeededRandomNumberGenerator(seed: seed)
            let shuffled = allQuestions.shuffled(using: &rng)
            return Array(shuffled.prefix(count))
        }
        let shuffled = allQuestions.shuffled()
        return Array(shuffled.prefix(count))
    }
}

// MARK: - Deterministic RNG (splitmix64)
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: String) {
        var hasher = Hasher()
        hasher.combine(seed)
        let hash = UInt64(bitPattern: Int64(hasher.finalize()))
        self.state = hash == 0 ? 0x9E3779B97F4A7C15 : hash
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z &>> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z &>> 27)) &* 0x94D049BB133111EB
        return z ^ (z &>> 31)
    }
}

extension QuizQuestion {
    init(from raw: RawQuestion) {
        self.id = raw.question_id
        self.question = raw.question
        self.choices = raw.choices
        self.correctIndices = Set(raw.correct.compactMap { Int($0) })
        self.isMultiSelect = raw.correct.count > 1
        self.year = raw.year
        self.category = Int(raw.category) ?? 1
        self.explanationLink = raw.explanation.link
    }
}

// MARK: - Answer Evaluation
extension ExamSession {
    mutating func submit(answer selectedIndices: Set<Int>, for question: QuizQuestion) {
        let isCorrect = selectedIndices == question.correctIndices
        answers[question.id] = UserAnswer(
            questionID: question.id,
            selectedIndices: selectedIndices,
            isCorrect: isCorrect
        )
    }
}
