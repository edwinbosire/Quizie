import Foundation
import Observation

// MARK: - Quiz Configuration

struct QuizConfiguration: Equatable, Hashable, Sendable {
    let questionCount: Int
    let timeLimitSeconds: Int
    let passMarkCount: Int

    nonisolated static let practice = QuizConfiguration(
        questionCount: 24,
        timeLimitSeconds: 45 * 60,
        passMarkCount: 18
    )

    nonisolated static let mock = QuizConfiguration(
        questionCount: 24,
        timeLimitSeconds: 45 * 60,
        passMarkCount: 18
    )

    static func custom(
        questionCount: Int,
        timeLimitSeconds: Int,
        passMarkCount: Int
    ) -> QuizConfiguration {
        QuizConfiguration(
            questionCount: questionCount,
            timeLimitSeconds: timeLimitSeconds,
            passMarkCount: passMarkCount
        )
    }

    var durationMinutes: Int { timeLimitSeconds / 60 }

    var passPercentage: Int {
        guard questionCount > 0 else { return 0 }
        return Int((Double(passMarkCount) / Double(questionCount) * 100).rounded())
    }

    var summaryLabel: String {
        "\(questionCount) questions · \(durationMinutes) min"
    }
}

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
    var testID: String?
    let configuration: QuizConfiguration
    let questions: [QuizQuestion]
    var answers: [String: UserAnswer]   // keyed by question ID
    var startedAt: Date
    var finishedAt: Date?

    init(
        testID: String? = nil,
        configuration: QuizConfiguration = .practice,
        questions: [QuizQuestion],
        answers: [String: UserAnswer] = [:],
        startedAt: Date = Date(),
        finishedAt: Date? = nil
    ) {
        self.testID = testID
        self.configuration = configuration
        self.questions = questions
        self.answers = answers
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }

    var score: Int {
        answers.values.filter { $0.isCorrect }.count
    }

    var passed: Bool {
        score >= configuration.passMarkCount
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

    init(questions: [QuizQuestion]? = nil) {
        if let questions {
            allQuestions = questions
        } else {
            load()
        }
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
    func generateExam(count: Int = QuizConfiguration.practice.questionCount, seed: String? = nil) -> [QuizQuestion] {
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
        // FNV-1a is stable across launches, unlike Swift's randomized Hasher.
        let hash = seed.utf8.reduce(UInt64(0xcbf29ce484222325)) { hash, byte in
            (hash ^ UInt64(byte)) &* 0x100000001b3
        }
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
