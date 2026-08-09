import Foundation

@MainActor
struct FlashcardCatalog {
    static let newSessionLimit = 20

    let guideCards: [Flashcard]
    let contentError: String?

    init(repository: any QuestionRepository) {
        do {
            guideCards = try repository
                .questions(count: Int.max, seed: "flashcard-guide-catalog-v1")
                .map(Flashcard.init(question:))
            contentError = nil
        } catch {
            guideCards = []
            contentError = error.localizedDescription
        }
    }

    init(cards: [Flashcard]) {
        guideCards = cards
        contentError = nil
    }

    var chapterNumbers: [Int] {
        Array(Set(guideCards.compactMap(\.chapter))).sorted()
    }

    func allCards(memory: FlashcardMemory) -> [Flashcard] {
        guideCards + memory.customCards.map(\.flashcard)
    }

    func progressSummary(memory: FlashcardMemory) -> FlashcardProgressSummary {
        memory.progressSummary(totalAvailable: allCards(memory: memory).count)
    }

    func cards(
        for deck: FlashcardDeck,
        memory: FlashcardMemory,
        at date: Date
    ) -> [Flashcard] {
        let all = allCards(memory: memory)
        let candidates: [Flashcard]

        switch deck {
        case .newCards:
            candidates = all.filter { memory.review(for: $0.id) == nil }
        case .due:
            candidates = all.filter { memory.isDue($0, at: date) }
        case .chapter(let number):
            candidates = all.filter { $0.chapter == number && memory.isAvailable($0, at: date) }
        case .dates:
            candidates = all.filter { $0.isDateCard && memory.isAvailable($0, at: date) }
        case .custom:
            candidates = all.filter { $0.isCustom && memory.isAvailable($0, at: date) }
        }

        if deck == .newCards {
            return Array(candidates.prefix(Self.newSessionLimit))
        }
        return candidates
    }

    func totalCount(for deck: FlashcardDeck, memory: FlashcardMemory) -> Int {
        let all = allCards(memory: memory)
        switch deck {
        case .newCards: return all.count
        case .due: return memory.learningCount
        case .chapter(let number): return all.filter { $0.chapter == number }.count
        case .dates: return all.filter(\.isDateCard).count
        case .custom: return all.filter(\.isCustom).count
        }
    }

    func masteredCount(for deck: FlashcardDeck, memory: FlashcardMemory) -> Int {
        let all = allCards(memory: memory)
        let matching: [Flashcard]
        switch deck {
        case .chapter(let number): matching = all.filter { $0.chapter == number }
        case .dates: matching = all.filter(\.isDateCard)
        case .custom: matching = all.filter(\.isCustom)
        case .newCards, .due: matching = all
        }
        return matching.filter { memory.review(for: $0.id)?.rating == .known }.count
    }

    func revisedCount(for deck: FlashcardDeck, memory: FlashcardMemory) -> Int {
        let all = allCards(memory: memory)
        let matching: [Flashcard]
        switch deck {
        case .chapter(let number): matching = all.filter { $0.chapter == number }
        case .dates: matching = all.filter(\.isDateCard)
        case .custom: matching = all.filter(\.isCustom)
        case .newCards, .due: matching = all
        }
        return matching.filter { memory.review(for: $0.id) != nil }.count
    }
}
