import Foundation

struct MatchGameState {
    enum Phase: Equatable {
        case ready
        case playing
        case finished
    }

    static let wrongMatchPenalty: TimeInterval = 3

    private(set) var cards: [MatchGameCard]
    private(set) var phase: Phase = .ready
    private(set) var selectedCardID: String?
    private(set) var matchedPairIDs: Set<String> = []
    private(set) var incorrectCardIDs: Set<String> = []
    private(set) var mistakeCount = 0
    private(set) var startedAt: Date?
    private(set) var finalTime: TimeInterval?

    init(pairs: [MatchPair] = MatchPair.lifeInTheUK, shuffleCards: Bool = true) {
        let allCards = pairs.flatMap { pair in
            [
                MatchGameCard(
                    id: "\(pair.id)-term",
                    pairID: pair.id,
                    text: pair.term,
                    kind: .term
                ),
                MatchGameCard(
                    id: "\(pair.id)-definition",
                    pairID: pair.id,
                    text: pair.definition,
                    kind: .definition
                )
            ]
        }
        cards = shuffleCards ? allCards.shuffled() : allCards
    }

    var matchedCount: Int {
        matchedPairIDs.count
    }

    var pairCount: Int {
        cards.count / 2
    }

    var penaltyTime: TimeInterval {
        Double(mistakeCount) * Self.wrongMatchPenalty
    }

    mutating func start(at date: Date = .now) {
        phase = .playing
        selectedCardID = nil
        matchedPairIDs = []
        incorrectCardIDs = []
        mistakeCount = 0
        startedAt = date
        finalTime = nil
    }

    mutating func restart(at date: Date = .now) {
        cards.shuffle()
        start(at: date)
    }

    mutating func select(cardID: String, at date: Date = .now) {
        guard phase == .playing,
              let card = cards.first(where: { $0.id == cardID }),
              !matchedPairIDs.contains(card.pairID) else {
            return
        }

        incorrectCardIDs = []

        guard let selectedCardID else {
            self.selectedCardID = cardID
            return
        }

        guard selectedCardID != cardID,
              let selectedCard = cards.first(where: { $0.id == selectedCardID }) else {
            return
        }

        self.selectedCardID = nil
        resolveMatch(between: selectedCard, and: card, at: date)
    }

    mutating func match(cardID: String, with targetCardID: String, at date: Date = .now) {
        guard phase == .playing,
              cardID != targetCardID,
              let card = cards.first(where: { $0.id == cardID }),
              let targetCard = cards.first(where: { $0.id == targetCardID }),
              !matchedPairIDs.contains(card.pairID),
              !matchedPairIDs.contains(targetCard.pairID) else {
            return
        }

        selectedCardID = nil
        incorrectCardIDs = []
        resolveMatch(between: card, and: targetCard, at: date)
    }

    private mutating func resolveMatch(
        between firstCard: MatchGameCard,
        and secondCard: MatchGameCard,
        at date: Date
    ) {
        if firstCard.pairID == secondCard.pairID && firstCard.kind != secondCard.kind {
            matchedPairIDs.insert(firstCard.pairID)
            if matchedPairIDs.count == pairCount {
                finalTime = elapsedTime(at: date)
                phase = .finished
            }
        } else {
            mistakeCount += 1
            incorrectCardIDs = [firstCard.id, secondCard.id]
        }
    }

    func elapsedTime(at date: Date = .now) -> TimeInterval {
        if let finalTime {
            return finalTime
        }
        guard let startedAt else {
            return 0
        }
        return max(0, date.timeIntervalSince(startedAt)) + penaltyTime
    }

    func isMatched(_ card: MatchGameCard) -> Bool {
        matchedPairIDs.contains(card.pairID)
    }
}
