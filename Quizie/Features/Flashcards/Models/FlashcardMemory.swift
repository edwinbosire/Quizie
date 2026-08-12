import Foundation
import Observation
import SwiftData

@Model
final class FlashcardReview {
    @Attribute(.unique) var cardID: String
    var ratingRawValue: String
    var lastReviewedAt: Date
    var nextReviewAt: Date?
    var reviewCount: Int
    var knownCount: Int
    var learningCount: Int

    init(snapshot: FlashcardReviewSnapshot) {
        cardID = snapshot.cardID
        ratingRawValue = snapshot.rating.rawValue
        lastReviewedAt = snapshot.lastReviewedAt
        nextReviewAt = snapshot.nextReviewAt
        reviewCount = snapshot.reviewCount
        knownCount = snapshot.knownCount
        learningCount = snapshot.learningCount
    }

    var snapshot: FlashcardReviewSnapshot {
        FlashcardReviewSnapshot(
            cardID: cardID,
            rating: FlashcardRating(rawValue: ratingRawValue) ?? .learning,
            lastReviewedAt: lastReviewedAt,
            nextReviewAt: nextReviewAt,
            reviewCount: reviewCount,
            knownCount: knownCount,
            learningCount: learningCount
        )
    }

    func apply(_ value: FlashcardReviewSnapshot) {
        ratingRawValue = value.rating.rawValue
        lastReviewedAt = value.lastReviewedAt
        nextReviewAt = value.nextReviewAt
        reviewCount = value.reviewCount
        knownCount = value.knownCount
        learningCount = value.learningCount
    }
}

@Model
final class CustomFlashcard {
    @Attribute(.unique) var id: String
    var prompt: String
    var answer: String
    var chapter: Int?
    var isDateCard: Bool
    var createdAt: Date
    var sourceBlockIDs: [String] = []

    init(snapshot: CustomFlashcardSnapshot) {
        id = snapshot.id
        prompt = snapshot.prompt
        answer = snapshot.answer
        chapter = snapshot.chapter
        isDateCard = snapshot.isDateCard
        createdAt = snapshot.createdAt
        sourceBlockIDs = snapshot.sourceBlockIDs
    }

    var snapshot: CustomFlashcardSnapshot {
        CustomFlashcardSnapshot(
            id: id,
            prompt: prompt,
            answer: answer,
            chapter: chapter,
            isDateCard: isDateCard,
            createdAt: createdAt,
            sourceBlockIDs: sourceBlockIDs
        )
    }
}

@MainActor
protocol FlashcardMemoryStore: AnyObject {
    func fetchReviews() throws -> [FlashcardReviewSnapshot]
    func fetchCustomCards() throws -> [CustomFlashcardSnapshot]
    func upsertReview(_ review: FlashcardReviewSnapshot) throws
    func saveCustomCard(_ card: CustomFlashcardSnapshot) throws
}

@MainActor
final class SwiftDataFlashcardMemoryStore: FlashcardMemoryStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchReviews() throws -> [FlashcardReviewSnapshot] {
        try context.fetch(FetchDescriptor<FlashcardReview>()).map(\.snapshot)
    }

    func fetchCustomCards() throws -> [CustomFlashcardSnapshot] {
        let descriptor = FetchDescriptor<CustomFlashcard>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map(\.snapshot)
    }

    func upsertReview(_ review: FlashcardReviewSnapshot) throws {
        let cardID = review.cardID
        let descriptor = FetchDescriptor<FlashcardReview>(
            predicate: #Predicate { $0.cardID == cardID }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.apply(review)
        } else {
            context.insert(FlashcardReview(snapshot: review))
        }
        try context.save()
    }

    func saveCustomCard(_ card: CustomFlashcardSnapshot) throws {
        context.insert(CustomFlashcard(snapshot: card))
        try context.save()
    }
}

@MainActor
final class InMemoryFlashcardMemoryStore: FlashcardMemoryStore {
    private var reviews: [String: FlashcardReviewSnapshot]
    private var customCards: [String: CustomFlashcardSnapshot]

    init(
        reviews: [FlashcardReviewSnapshot] = [],
        customCards: [CustomFlashcardSnapshot] = []
    ) {
        self.reviews = Dictionary(uniqueKeysWithValues: reviews.map { ($0.cardID, $0) })
        self.customCards = Dictionary(uniqueKeysWithValues: customCards.map { ($0.id, $0) })
    }

    func fetchReviews() throws -> [FlashcardReviewSnapshot] { Array(reviews.values) }

    func fetchCustomCards() throws -> [CustomFlashcardSnapshot] {
        customCards.values.sorted { $0.createdAt > $1.createdAt }
    }

    func upsertReview(_ review: FlashcardReviewSnapshot) throws {
        reviews[review.cardID] = review
    }

    func saveCustomCard(_ card: CustomFlashcardSnapshot) throws {
        customCards[card.id] = card
    }
}

@MainActor
@Observable
final class FlashcardMemory {
    static let learningInterval: TimeInterval = 10 * 60

    private let store: any FlashcardMemoryStore
    private let issues: PersistenceIssueCenter
    private(set) var reviews: [String: FlashcardReviewSnapshot] = [:]
    private(set) var customCards: [CustomFlashcardSnapshot] = []

    init(store: any FlashcardMemoryStore, issues: PersistenceIssueCenter) {
        self.store = store
        self.issues = issues
        reload()
    }

    var learningCount: Int {
        reviews.values.filter { $0.rating == .learning }.count
    }

    func progressSummary(totalAvailable: Int) -> FlashcardProgressSummary {
        FlashcardProgressSummary(
            totalAvailable: totalAvailable,
            reviewed: reviews.count,
            mastered: reviews.values.filter { $0.rating == .known }.count,
            learning: learningCount,
            totalReviews: reviews.values.reduce(0) { $0 + $1.reviewCount }
        )
    }

    func review(for cardID: String) -> FlashcardReviewSnapshot? { reviews[cardID] }

    func isAvailable(_ card: Flashcard, at date: Date) -> Bool {
        guard let review = reviews[card.id] else { return true }
        guard review.rating == .learning, let dueDate = review.nextReviewAt else { return false }
        return dueDate <= date
    }

    func isDue(_ card: Flashcard, at date: Date) -> Bool {
        guard let review = reviews[card.id], review.rating == .learning else { return false }
        return review.nextReviewAt.map { $0 <= date } ?? false
    }

    func record(_ rating: FlashcardRating, for card: Flashcard, at date: Date = Date()) {
        let previous = reviews[card.id]
        let value = FlashcardReviewSnapshot(
            cardID: card.id,
            rating: rating,
            lastReviewedAt: date,
            nextReviewAt: rating == .learning ? date.addingTimeInterval(Self.learningInterval) : nil,
            reviewCount: (previous?.reviewCount ?? 0) + 1,
            knownCount: (previous?.knownCount ?? 0) + (rating == .known ? 1 : 0),
            learningCount: (previous?.learningCount ?? 0) + (rating == .learning ? 1 : 0)
        )

        do {
            try store.upsertReview(value)
            reviews[card.id] = value
        } catch {
            issues.report(error, operation: "Saving flashcard progress")
        }
    }

    func createCard(
        prompt: String,
        answer: String,
        chapter: Int?,
        isDateCard: Bool,
        sourceBlockIDs: [String] = [],
        at date: Date = Date()
    ) {
        let value = CustomFlashcardSnapshot(
            id: "custom-\(UUID().uuidString.lowercased())",
            prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines),
            answer: answer.trimmingCharacters(in: .whitespacesAndNewlines),
            chapter: chapter,
            isDateCard: isDateCard,
            createdAt: date,
            sourceBlockIDs: sourceBlockIDs
        )

        do {
            try store.saveCustomCard(value)
            customCards.insert(value, at: 0)
        } catch {
            issues.report(error, operation: "Saving custom flashcard")
        }
    }

    func reload() {
        do {
            reviews = Dictionary(uniqueKeysWithValues: try store.fetchReviews().map { ($0.cardID, $0) })
            customCards = try store.fetchCustomCards()
        } catch {
            issues.report(error, operation: "Loading flashcard progress")
        }
    }
}
