import Foundation

// MARK: - Quiz Configuration

enum QuizMode: Equatable, Hashable, Sendable {
    case exam
    case practice
    case streak

    var isExam: Bool { self == .exam }

    func allowsHints(hasAnsweredQuestion: Bool) -> Bool {
        !isExam || hasAnsweredQuestion
    }

    var allowsBookAccess: Bool { !isExam }
}

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
    let taxonomy: ContentTaxonomyTags?
}

struct RawExplanation: Codable {
    let link: String
}

struct RawQuestionsFile: Codable {
    let schemaVersion: Int?
    let taxonomyVersion: String?
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
    let taxonomy: ContentTaxonomyTags

    init(id: String, question: String, choices: [String], correctIndices: Set<Int>, isMultiSelect: Bool, year: String, category: Int, explanationLink: String, taxonomy: ContentTaxonomyTags = .empty) {
        self.id = id
        self.question = question
        self.choices = choices
        self.correctIndices = correctIndices
        self.isMultiSelect = isMultiSelect
        self.year = year
        self.category = category
        self.explanationLink = explanationLink
        self.taxonomy = taxonomy
    }

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
    let mode: QuizMode
    let configuration: QuizConfiguration
    let questions: [QuizQuestion]
    var answers: [String: UserAnswer]   // keyed by question ID
    var startedAt: Date
    var finishedAt: Date?

    init(
        testID: String? = nil,
        mode: QuizMode = .practice,
        configuration: QuizConfiguration = .practice,
        questions: [QuizQuestion],
        answers: [String: UserAnswer] = [:],
        startedAt: Date = Date(),
        finishedAt: Date? = nil
    ) {
        self.testID = testID
        self.mode = mode
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

@MainActor
enum QuestionDocumentDecoder {
    static func decode(_ data: Data, decoder: JSONDecoder = JSONDecoder()) throws -> [QuizQuestion] {
        try decoder.decode(RawQuestionsFile.self, from: data).data.map(QuizQuestion.init(from:))
    }
}

enum QuestionSelector {
    static func select(from questions: [QuizQuestion], count: Int, seed: String?) -> [QuizQuestion] {
        guard !questions.isEmpty, count > 0 else { return [] }
        if let seed {
            var rng = SeededRandomNumberGenerator(seed: seed)
            return Array(questions.shuffled(using: &rng).prefix(count))
        }
        return Array(questions.shuffled().prefix(count))
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
        self.taxonomy = raw.taxonomy ?? .empty
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
