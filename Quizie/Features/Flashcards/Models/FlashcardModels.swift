import Foundation

struct Flashcard: Identifiable, Equatable, Sendable {
    let id: String
    let prompt: String
    let answer: String
    let topic: String
    let chapter: Int?
    let year: String?
    let isCustom: Bool

    init(
        id: String,
        prompt: String,
        answer: String,
        topic: String,
        chapter: Int? = nil,
        year: String? = nil,
        isCustom: Bool = false
    ) {
        self.id = id
        self.prompt = prompt
        self.answer = answer
        self.topic = topic
        self.chapter = chapter
        self.year = year?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.isCustom = isCustom
    }

    var isDateCard: Bool { year != nil }
}

enum FlashcardRating: String, Codable, Equatable, Sendable {
    case learning
    case known
}

enum FlashcardDeck: Hashable, Identifiable, Sendable {
    case newCards
    case due
    case chapter(Int)
    case dates
    case custom

    var id: String {
        switch self {
        case .newCards: return "new"
        case .due: return "due"
        case .chapter(let number): return "chapter-\(number)"
        case .dates: return "dates"
        case .custom: return "custom"
        }
    }

    var title: String {
        switch self {
        case .newCards: return "New flashcards"
        case .due: return "Upcoming practice"
        case .chapter(let number): return Self.chapterTitle(for: number)
        case .dates: return "Important dates"
        case .custom: return "My flashcards"
        }
    }

    private static func chapterTitle(for number: Int) -> String {
        switch number {
        case 1: return "Chapter 1: The values and principles of the UK"
        case 2: return "Chapter 2: What is the UK?"
        case 3: return "Chapter 3: A long and illustrious history"
        case 4: return "Chapter 4: A modern, thriving society"
        case 5: return "Chapter 5: The UK Government, the law and your role"
        default: return "Chapter \(number)"
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

    var flashcard: Flashcard {
        Flashcard(
            id: id,
            prompt: prompt,
            answer: answer,
            topic: isDateCard ? "Important dates" : chapter.map { "Chapter \($0)" } ?? "My flashcards",
            chapter: chapter,
            year: isDateCard ? "Custom" : nil,
            isCustom: true
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
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
