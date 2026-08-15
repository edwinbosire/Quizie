import Foundation
import Observation

@MainActor
@Observable
final class FlashcardSession {
    static let defaultDeckSize = 20
    static let learningGap = 3

    private(set) var cards: [Flashcard]
    private(set) var currentIndex = 0
    private(set) var ratings: [String: FlashcardRating] = [:]
    private(set) var isComplete = false
    var isShowingAnswer = false
    let contentError: String?

    private let memory: FlashcardMemory?
    private let clock: any QuizClock

    convenience init(cards: [Flashcard]) {
        self.init(cards: cards, memory: nil, clock: SystemQuizClock())
    }

    init(
        cards: [Flashcard],
        memory: FlashcardMemory?,
        clock: any QuizClock
    ) {
        self.cards = cards
        self.memory = memory
        self.clock = clock
        contentError = nil
        isComplete = cards.isEmpty
    }

    var currentCard: Flashcard? {
        guard cards.indices.contains(currentIndex) else { return nil }
        return cards[currentIndex]
    }

    var knownCount: Int {
        ratings.values.filter(\.isKnown).count
    }

    var learningCount: Int {
        ratings.values.filter(\.isLearning).count
    }

    var positionLabel: String {
        guard !cards.isEmpty else { return "0 / 0" }
        return "\(min(currentIndex + 1, cards.count)) / \(cards.count)"
    }

    var progress: Double {
        guard !cards.isEmpty else { return 0 }
        return isComplete ? 1 : Double(currentIndex) / Double(cards.count)
    }

    var completionPercentage: Int {
        guard !ratings.isEmpty else { return 0 }
        return Int((Double(knownCount) / Double(ratings.count) * 100).rounded())
    }

    func flip() {
        guard currentCard != nil else { return }
        isShowingAnswer.toggle()
    }

    func rate(_ rating: FlashcardRating) {
        guard let currentCard else { return }
        ratings[currentCard.id] = rating
        memory?.record(rating, for: currentCard, at: clock.now)
        if rating.isLearning {
            scheduleLearningCardIfUseful(currentCard)
        }
        advance()
    }

    private func scheduleLearningCardIfUseful(_ card: Flashcard) {
        let cardsRemaining = cards.count - currentIndex - 1
        guard cardsRemaining >= Self.learningGap else { return }

        let insertionIndex = min(currentIndex + Self.learningGap + 1, cards.count)
        let scheduledRange = insertionIndex..<cards.count
        guard !scheduledRange.contains(where: { cards[$0].id == card.id }) else { return }
        cards.insert(card, at: insertionIndex)
    }

    private func advance() {
        if currentIndex == cards.count - 1 {
            isComplete = true
            isShowingAnswer = false
        } else {
            currentIndex += 1
            isShowingAnswer = false
        }
    }
}
