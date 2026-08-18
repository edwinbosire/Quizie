import Foundation

struct Flashcard: Identifiable, Equatable, Sendable {
    let id: String
    let prompt: String
    let answer: String
    let topic: String
    let chapter: Int?
    let year: String?
    let isCustom: Bool
    let taxonomy: ContentTaxonomyTags

    init(
        id: String,
        prompt: String,
        answer: String,
        topic: String,
        chapter: Int? = nil,
        year: String? = nil,
        isCustom: Bool = false,
        taxonomy: ContentTaxonomyTags = .empty
    ) {
        self.id = id
        self.prompt = prompt
        self.answer = answer
        self.topic = topic
        self.chapter = chapter
        self.year = year?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.isCustom = isCustom
        self.taxonomy = taxonomy
    }

    var isDateCard: Bool { year != nil }
}

enum FlashcardRating: String, Codable, Equatable, Sendable {
    case again
    case hard
    case good
    case easy
    case learning
    case known

    nonisolated var analyticsScoreKey: FlashcardRating {
        switch self {
        case .learning: .again
        case .known: .good
        default: self
        }
    }

    nonisolated var isLearning: Bool { [.again, .hard].contains(analyticsScoreKey) }
    nonisolated var isKnown: Bool { [.good, .easy].contains(analyticsScoreKey) }
}

enum FlashcardDeck: Hashable, Identifiable, Sendable {
    case newCards
    case due
    case chapter(Int)
    case concept(ids: [String], title: String)
    case dates
    case custom

    var id: String {
        switch self {
        case .newCards: return "new"
        case .due: return "due"
        case .chapter(let number): return "chapter-\(number)"
        case .concept(let ids, _): return "concept-\(ids.joined(separator: "."))"
        case .dates: return "dates"
        case .custom: return "custom"
        }
    }

    var title: String {
        switch self {
        case .newCards: return "New flashcards"
        case .due: return "Upcoming practice"
        case .chapter(let number):
            guard let name = Self.chapterName(for: number) else { return "Chapter \(number)" }
            return "Chapter \(number): \(name)"
        case .concept(_, let title): return title
        case .dates: return "Important dates"
        case .custom: return "My flashcards"
        }
    }

    static func chapterName(for number: Int) -> String? {
        switch number {
        case 1: return "The values and principles of the UK"
        case 2: return "What is the UK?"
        case 3: return "A long and illustrious history"
        case 4: return "A modern, thriving society"
        case 5: return "The UK Government, the law and your role"
        default: return nil
        }
    }
}

struct FlashcardReviewSnapshot: Equatable, Sendable {
    let cardID: String
    let rating: FlashcardRating
    let lastReviewedAt: Date
    let nextReviewAt: Date?
    let reviewCount: Int
    let knownCount: Int
    let learningCount: Int
}

struct CustomFlashcardSnapshot: Identifiable, Equatable, Sendable {
    let id: String
    let prompt: String
    let answer: String
    let chapter: Int?
    let isDateCard: Bool
    let createdAt: Date
    let sourceBlockIDs: [String]
    let taxonomy: ContentTaxonomyTags

    init(id: String, prompt: String, answer: String, chapter: Int?, isDateCard: Bool, createdAt: Date, sourceBlockIDs: [String] = [], taxonomy: ContentTaxonomyTags = .empty) {
        self.id = id
        self.prompt = prompt
        self.answer = answer
        self.chapter = chapter
        self.isDateCard = isDateCard
        self.createdAt = createdAt
        self.sourceBlockIDs = sourceBlockIDs
        self.taxonomy = taxonomy
    }

    var flashcard: Flashcard {
        Flashcard(
            id: id,
            prompt: prompt,
            answer: answer,
            topic: isDateCard ? "Important dates" : chapter.map { "Chapter \($0)" } ?? "My flashcards",
            chapter: chapter,
            year: isDateCard ? "Custom" : nil,
            isCustom: true,
            taxonomy: taxonomy
        )
    }
}

struct FlashcardProgressSummary: Equatable, Sendable {
    let totalAvailable: Int
    let reviewed: Int
    let mastered: Int
    let learning: Int
    let totalReviews: Int

    var masteryPercentage: Int {
        guard totalAvailable > 0 else { return 0 }
        return Int((Double(mastered) / Double(totalAvailable) * 100).rounded())
    }
}

nonisolated enum BundledFlashcardIssue: String, Equatable, Sendable {
    case multipleAnswers
    case nonAtomicPrompt
    case nonMinimalAnswer
}

nonisolated enum BundledFlashcardAuditOutcome: Equatable, Sendable {
    case repaired
    case excluded
}

nonisolated struct BundledFlashcardAuditEntry: Equatable, Sendable {
    let questionID: String
    let issues: [BundledFlashcardIssue]
    let outcome: BundledFlashcardAuditOutcome
    let repairedPrompt: String?
}

nonisolated struct BundledFlashcardConversion: Sendable {
    let card: Flashcard?
    let auditEntry: BundledFlashcardAuditEntry?
}

enum BundledFlashcardConverter {
    static func convert(_ question: QuizQuestion) -> BundledFlashcardConversion {
        let answers = question.correctChoices.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var issues: [BundledFlashcardIssue] = []
        if answers.count != 1 { issues.append(.multipleAnswers) }
        if !FlashcardRecallStyle.isAtomicQuestion(question.question) { issues.append(.nonAtomicPrompt) }
        if answers.count != 1 || answers.contains(where: { !FlashcardRecallStyle.isMinimalAnswer($0) }) { issues.append(.nonMinimalAnswer) }

        guard answers.count == 1 else { return excluded(question, issues: issues) }
        var answer = answers[0]
        var prompt = question.question.trimmingCharacters(in: .whitespacesAndNewlines)
        if !FlashcardRecallStyle.isMinimalAnswer(answer), let repaired = repairAnswer(answer) {
            answer = repaired
        }
        if !FlashcardRecallStyle.isAtomicQuestion(prompt), let repaired = repairChoiceDependentCard(prompt: prompt, answer: answer) {
            prompt = repaired.prompt
            answer = repaired.answer
        }

        if let repaired = repairBiographicalCard(prompt: prompt, answer: answer), FlashcardRecallStyle.isValid(question: repaired.prompt, answer: repaired.answer) {
            return BundledFlashcardConversion(card: makeCard(question, prompt: repaired.prompt, answer: repaired.answer), auditEntry: BundledFlashcardAuditEntry(questionID: question.id, issues: issues, outcome: .repaired, repairedPrompt: repaired.prompt))
        }

        guard FlashcardRecallStyle.isValid(question: prompt, answer: answer) else { return excluded(question, issues: issues) }
        let audit = issues.isEmpty ? nil : BundledFlashcardAuditEntry(questionID: question.id, issues: issues, outcome: .repaired, repairedPrompt: prompt)
        return BundledFlashcardConversion(card: makeCard(question, prompt: prompt, answer: answer), auditEntry: audit)
    }

    private static func makeCard(_ question: QuizQuestion, prompt: String, answer: String) -> Flashcard {
        Flashcard(id: "guide-\(question.id)", prompt: prompt, answer: answer, topic: "Chapter \(question.category)", chapter: question.category, year: question.year, taxonomy: question.taxonomy)
    }

    private static func excluded(_ question: QuizQuestion, issues: [BundledFlashcardIssue]) -> BundledFlashcardConversion {
        BundledFlashcardConversion(card: nil, auditEntry: BundledFlashcardAuditEntry(questionID: question.id, issues: issues, outcome: .excluded, repairedPrompt: nil))
    }

    private static func repairAnswer(_ answer: String) -> String? {
        if let groups = captures(#"^(.+?)\s+also\s+.+$"#, in: answer), groups.count == 1 { return groups[0] }
        if let groups = captures(#"^([A-Z][A-Z0-9.-]+)\s+\([^)]+\)$"#, in: answer), groups.count == 1 { return groups[0] }
        return nil
    }

    private static func repairChoiceDependentCard(prompt: String, answer: String) -> (prompt: String, answer: String)? {
        let prefixPattern = #"^Which of (?:these|the following) (.+)\?$"#
        guard let groups = captures(prefixPattern, in: prompt), groups.count == 1 else { return nil }
        let remainder = groups[0]
        guard let verbRange = remainder.range(of: #"\s+(?:is|was)\s+"#, options: [.regularExpression, .caseInsensitive]) else { return nil }
        let predicate = String(remainder[verbRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard predicate.range(of: #"\b(?:not|correct|incorrect|true|false)\b"#, options: [.regularExpression, .caseInsensitive]) == nil else { return nil }
        let subject = lowercasingLeadingArticle(answer.trimmingCharacters(in: .whitespacesAndNewlines))

        if let location = captures(#"^(?:located\s+)?in\s+(.+)$"#, in: predicate)?.first {
            return ("Where is \(subject) located?", uppercasingFirstCharacter(location))
        }
        return ("What is \(subject)?", uppercasingFirstCharacter(predicate))
    }

    private static func repairBiographicalCard(prompt: String, answer: String) -> (prompt: String, answer: String)? {
        guard let groups = captures(#"^Who was ([^?]+)\?$"#, in: prompt), groups.count == 1 else { return nil }
        let person = groups[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard FlashcardRecallStyle.isMinimalAnswer(person), answer.range(of: #"[;\n•]|\band\b"#, options: [.regularExpression, .caseInsensitive]) == nil else { return nil }
        let descriptor = answer.replacingOccurrences(of: #"^Was\s+"#, with: "", options: [.regularExpression, .caseInsensitive])
        let trimmedDescriptor = descriptor.trimmingCharacters(in: CharacterSet(charactersIn: ".!? "))
        guard FlashcardRecallStyle.wordCount(trimmedDescriptor) >= 4 else { return nil }
        return ("Who was \(lowercasingFirstCharacter(trimmedDescriptor))?", person)
    }

    private static func captures(_ pattern: String, in value: String) -> [String]? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive), let match = expression.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)), match.range == NSRange(value.startIndex..., in: value) else { return nil }
        return (1..<match.numberOfRanges).compactMap { Range(match.range(at: $0), in: value).map { String(value[$0]) } }
    }

    private static func lowercasingFirstCharacter(_ value: String) -> String {
        guard let first = value.first else { return value }
        return first.lowercased() + value.dropFirst()
    }

    private static func lowercasingLeadingArticle(_ value: String) -> String {
        for article in ["The", "An", "A"] where value.hasPrefix("\(article) ") {
            return article.lowercased() + value.dropFirst(article.count)
        }
        return value
    }

    private static func uppercasingFirstCharacter(_ value: String) -> String {
        guard let first = value.first else { return value }
        return first.uppercased() + value.dropFirst()
    }
}

extension Flashcard {
    init?(question: QuizQuestion) {
        guard let card = BundledFlashcardConverter.convert(question).card else { return nil }
        self = card
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
