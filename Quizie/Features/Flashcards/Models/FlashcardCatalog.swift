import Foundation

@MainActor
struct FlashcardCatalog {
    static let newSessionLimit = 20

    let guideCards: [Flashcard]
    let guideCardAudit: [BundledFlashcardAuditEntry]
    let contentError: String?
    let chapterNumbers: [Int]

    init(repository: any QuestionRepository) {
        do {
            let conversions = try repository.questions(count: Int.max, seed: "flashcard-guide-catalog-v2").map(BundledFlashcardConverter.convert)
            let cards = conversions.compactMap(\.card)
            guideCards = cards
            guideCardAudit = conversions.compactMap(\.auditEntry)
            contentError = nil
            chapterNumbers = Self.chapterNumbers(in: cards)
        } catch {
            guideCards = []
            guideCardAudit = []
            contentError = error.localizedDescription
            chapterNumbers = []
        }
    }

    init(cards: [Flashcard]) {
        guideCards = cards
        guideCardAudit = []
        contentError = nil
        chapterNumbers = Self.chapterNumbers(in: cards)
    }

    private static func chapterNumbers(in cards: [Flashcard]) -> [Int] {
        Array(Set(cards.compactMap(\.chapter))).sorted()
    }

    var excludedGuideCardCount: Int { guideCardAudit.count { $0.outcome == .excluded } }
    var repairedGuideCardCount: Int { guideCardAudit.count { $0.outcome == .repaired } }

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
        case .concept(let ids, _):
            let conceptIDs = Set(ids)
            candidates = all.filter { !conceptIDs.isDisjoint(with: $0.taxonomy.conceptIds) && memory.isAvailable($0, at: date) }
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

    /// Whether a card belongs to `deck`, ignoring review state.
    private func matches(_ card: Flashcard, deck: FlashcardDeck) -> Bool {
        switch deck {
        case .newCards, .due: return true
        case .chapter(let number): return card.chapter == number
        case .concept(let ids, _): return !Set(ids).isDisjoint(with: card.taxonomy.conceptIds)
        case .dates: return card.isDateCard
        case .custom: return card.isCustom
        }
    }

    /// Folds over the guide and custom cards without materialising a combined
    /// array. The landing page queries these counts once per deck per redraw,
    /// so the allocation is worth avoiding.
    private func reduceCards<Result>(memory: FlashcardMemory, into initial: Result, _ step: (inout Result, Flashcard) -> Void) -> Result {
        var result = initial
        for card in guideCards { step(&result, card) }
        for custom in memory.customCards { step(&result, custom.flashcard) }
        return result
    }

    func totalCount(for deck: FlashcardDeck, memory: FlashcardMemory) -> Int {
        if case .due = deck { return memory.learningCount }
        return reduceCards(memory: memory, into: 0) { total, card in
            if matches(card, deck: deck) { total += 1 }
        }
    }

    func masteredCount(for deck: FlashcardDeck, memory: FlashcardMemory) -> Int {
        reduceCards(memory: memory, into: 0) { total, card in
            if matches(card, deck: deck), memory.review(for: card.id)?.rating.isKnown == true { total += 1 }
        }
    }

    func revisedCount(for deck: FlashcardDeck, memory: FlashcardMemory) -> Int {
        reduceCards(memory: memory, into: 0) { total, card in
            if matches(card, deck: deck), memory.review(for: card.id) != nil { total += 1 }
        }
    }

    /// Every count the flashcards landing page renders, gathered in a single
    /// pass over the card set. Asking for each deck separately made the page
    /// O(decks x cards); this makes a redraw O(cards).
    func landingStatistics(memory: FlashcardMemory, at date: Date) -> FlashcardLandingStatistics {
        var decks: [FlashcardDeck: FlashcardDeckStatistics] = [:]
        var newCardCount = 0
        var dueCount = 0
        var totalCards = 0

        func record(_ card: Flashcard, in deck: FlashcardDeck, isAvailable: Bool, review: FlashcardReviewSnapshot?) {
            var statistics = decks[deck] ?? FlashcardDeckStatistics()
            statistics.total += 1
            if isAvailable { statistics.available += 1 }
            if review != nil { statistics.revised += 1 }
            if review?.rating.isKnown == true { statistics.mastered += 1 }
            decks[deck] = statistics
        }

        reduceCards(memory: memory, into: ()) { _, card in
            let review = memory.review(for: card.id)
            let isAvailable = memory.isAvailable(card, at: date)
            totalCards += 1
            if review == nil { newCardCount += 1 }
            if memory.isDue(card, at: date) { dueCount += 1 }
            if let chapter = card.chapter { record(card, in: .chapter(chapter), isAvailable: isAvailable, review: review) }
            if card.isDateCard { record(card, in: .dates, isAvailable: isAvailable, review: review) }
            if card.isCustom { record(card, in: .custom, isAvailable: isAvailable, review: review) }
        }

        return FlashcardLandingStatistics(
            decks: decks,
            newCardCount: newCardCount,
            dueCount: dueCount,
            summary: memory.progressSummary(totalAvailable: totalCards)
        )
    }
}

struct FlashcardDeckStatistics: Equatable {
    var total = 0
    var mastered = 0
    var revised = 0
    var available = 0
}

struct FlashcardLandingStatistics: Equatable {
    let decks: [FlashcardDeck: FlashcardDeckStatistics]
    let newCardCount: Int
    let dueCount: Int
    let summary: FlashcardProgressSummary

    func statistics(for deck: FlashcardDeck) -> FlashcardDeckStatistics {
        decks[deck] ?? FlashcardDeckStatistics()
    }
}
