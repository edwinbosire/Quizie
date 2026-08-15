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

extension Flashcard {
    init(question: QuizQuestion) {
        id = "guide-\(question.id)"
        prompt = question.question
        answer = question.correctChoices.joined(separator: "\n")
        topic = "Chapter \(question.category)"
        chapter = question.category
        year = question.year.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        isCustom = false
        taxonomy = question.taxonomy
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
