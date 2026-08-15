import Foundation

nonisolated struct EvidenceNormalizer: Sendable {
    let configuration: AnalyticsConfiguration

    init(configuration: AnalyticsConfiguration = .v1) { self.configuration = configuration }

    func normalize(questionAttempts: [QuestionAttemptSnapshot], flashcardReviews: [FlashcardReviewEventSnapshot], taxonomy: ConceptTaxonomy, referenceDate: Date) -> [LearningEvidence] {
        let validIDs = Set(taxonomy.concepts.map(\.id))
        var result: [LearningEvidence] = []
        var repetitionCounts: [String: Int] = [:]

        for attempt in deduplicate(questionAttempts).sorted(by: questionOrder) {
            let repetitionKey = "\(attempt.source.rawValue):\(attempt.questionID)"
            let repetitionIndex = repetitionCounts[repetitionKey, default: 0]
            repetitionCounts[repetitionKey] = repetitionIndex + 1
            for concept in attempt.conceptWeights {
                guard let conceptID = canonical(concept.conceptID, validIDs: validIDs) else { continue }
                result.append(makeEvidence(id: derivedID(eventID: attempt.id, conceptID: conceptID), conceptID: conceptID, source: attempt.source, score: attempt.wasCorrect ? 1 : 0, conceptWeight: concept.weight, difficultyWeight: configuration.difficultyWeight(attempt.difficulty), repetitionIndex: repetitionIndex, sourceItemID: attempt.questionID, occurredAt: attempt.answeredAt, referenceDate: referenceDate))
            }
        }

        repetitionCounts = [:]
        for review in deduplicate(flashcardReviews).sorted(by: flashcardOrder) {
            let repetitionIndex = repetitionCounts[review.flashcardID, default: 0]
            repetitionCounts[review.flashcardID] = repetitionIndex + 1
            for rawConceptID in review.conceptIDs {
                guard let conceptID = canonical(rawConceptID, validIDs: validIDs) else { continue }
                result.append(makeEvidence(id: derivedID(eventID: review.id, conceptID: conceptID), conceptID: conceptID, source: .flashcard, score: configuration.flashcardScore(review.rating), conceptWeight: 1, difficultyWeight: 1, repetitionIndex: repetitionIndex, sourceItemID: review.flashcardID, occurredAt: review.reviewedAt, referenceDate: referenceDate))
            }
        }
        return result.sorted { $0.occurredAt == $1.occurredAt ? $0.id.uuidString < $1.id.uuidString : $0.occurredAt < $1.occurredAt }
    }

    private func makeEvidence(id: UUID, conceptID: String, source: EvidenceSource, score: Double, conceptWeight: Double, difficultyWeight: Double, repetitionIndex: Int, sourceItemID: String, occurredAt: Date, referenceDate: Date) -> LearningEvidence {
        let sourceWeight = configuration.sourceWeight(source)
        let ageInDays = max(0, referenceDate.timeIntervalSince(occurredAt) / 86_400)
        let recencyWeight = exp(-configuration.recencyDecayLambda * ageInDays)
        let repetitionWeight = configuration.repetitionWeight(at: repetitionIndex)
        let effectiveWeight = sourceWeight * difficultyWeight * conceptWeight * recencyWeight * repetitionWeight
        return LearningEvidence(id: id, conceptID: conceptID, source: source, score: min(max(score, 0), 1), sourceWeight: sourceWeight, conceptWeight: conceptWeight, difficultyWeight: difficultyWeight, recencyWeight: recencyWeight, repetitionWeight: repetitionWeight, effectiveWeight: max(0, effectiveWeight), sourceItemID: sourceItemID, occurredAt: occurredAt)
    }

    private func canonical(_ rawID: String, validIDs: Set<String>) -> String? {
        var value = rawID
        var seen = Set<String>()
        while let replacement = configuration.conceptIDReplacements[value], seen.insert(value).inserted { value = replacement }
        return validIDs.contains(value) ? value : nil
    }

    private func derivedID(eventID: UUID, conceptID: String) -> UUID {
        var rawUUID = eventID.uuid
        var bytes = withUnsafeBytes(of: &rawUUID) { Array($0) }
        for (index, byte) in conceptID.utf8.enumerated() { bytes[index % 16] ^= byte }
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    private func deduplicate(_ values: [QuestionAttemptSnapshot]) -> [QuestionAttemptSnapshot] {
        Dictionary(values.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values.map { $0 }
    }

    private func deduplicate(_ values: [FlashcardReviewEventSnapshot]) -> [FlashcardReviewEventSnapshot] {
        Dictionary(values.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values.map { $0 }
    }

    private func questionOrder(_ left: QuestionAttemptSnapshot, _ right: QuestionAttemptSnapshot) -> Bool {
        left.answeredAt == right.answeredAt ? left.id.uuidString < right.id.uuidString : left.answeredAt < right.answeredAt
    }

    private func flashcardOrder(_ left: FlashcardReviewEventSnapshot, _ right: FlashcardReviewEventSnapshot) -> Bool {
        left.reviewedAt == right.reviewedAt ? left.id.uuidString < right.id.uuidString : left.reviewedAt < right.reviewedAt
    }
}

nonisolated struct MasteryCalculator: Sendable {
    func mastery(for evidence: [LearningEvidence]) -> Double? {
        let denominator = evidence.reduce(0) { $0 + max(0, $1.effectiveWeight) }
        guard denominator > 0 else { return nil }
        let value = evidence.reduce(0) { $0 + min(max($1.score, 0), 1) * max(0, $1.effectiveWeight) } / denominator
        return min(max(value, 0), 1)
    }
}

nonisolated struct ConfidenceCalculator: Sendable {
    let configuration: AnalyticsConfiguration

    init(configuration: AnalyticsConfiguration = .v1) { self.configuration = configuration }

    func confidence(for evidence: [LearningEvidence]) -> Double {
        let uniqueCount = Set(evidence.map { "\($0.source.rawValue):\($0.sourceItemID)" }).count
        return min(max(1 - exp(-configuration.confidenceK * Double(uniqueCount)), 0), 1)
    }
}
