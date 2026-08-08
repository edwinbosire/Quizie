import Foundation
import Observation

@MainActor
@Observable
final class FlashcardSession {
    static let defaultDeckSize = 68

    private(set) var cards: [Flashcard]
    private(set) var currentIndex = 0
    private(set) var ratings: [String: FlashcardRating] = [:]
    private(set) var starredCardIDs: Set<String> = []
    private(set) var isComplete = false
    var isShowingAnswer = false
    let contentError: String?

    private let originalCards: [Flashcard]

    init(repository: any QuestionRepository, seed: String? = nil) {
        do {
            let cards = try repository
                .questions(count: Self.defaultDeckSize, seed: seed)
                .map(Flashcard.init(question:))
            self.cards = cards
            originalCards = cards
            contentError = nil
        } catch {
            cards = []
            originalCards = []
            contentError = error.localizedDescription
        }
    }

    init(cards: [Flashcard]) {
        self.cards = cards
        originalCards = cards
        contentError = nil
    }

    var currentCard: Flashcard? {
        guard cards.indices.contains(currentIndex) else { return nil }
        return cards[currentIndex]
    }

    var knownCount: Int {
        ratings.values.filter { $0 == .known }.count
    }

    var learningCount: Int {
        ratings.values.filter { $0 == .learning }.count
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

    var isCurrentCardStarred: Bool {
        guard let currentCard else { return false }
        return starredCardIDs.contains(currentCard.id)
    }

    var canGoBack: Bool {
        currentIndex > 0
    }

    func flip() {
        guard currentCard != nil else { return }
        isShowingAnswer.toggle()
    }

    func toggleStar() {
        guard let currentCard else { return }
        if starredCardIDs.contains(currentCard.id) {
            starredCardIDs.remove(currentCard.id)
        } else {
            starredCardIDs.insert(currentCard.id)
        }
    }

    func rate(_ rating: FlashcardRating) {
        guard let currentCard else { return }
        ratings[currentCard.id] = rating
        advance()
    }

    func goBack() {
        guard canGoBack else { return }
        currentIndex -= 1
        isShowingAnswer = false
        isComplete = false
    }

    func restart() {
        begin(cards: originalCards)
    }

    func reviewLearningCards() {
        let learningCards = originalCards.filter { ratings[$0.id] == .learning }
        guard !learningCards.isEmpty else { return }
        begin(cards: learningCards)
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

    private func begin(cards: [Flashcard]) {
        self.cards = cards
        currentIndex = 0
        ratings = [:]
        isShowingAnswer = false
        isComplete = cards.isEmpty
    }
}
