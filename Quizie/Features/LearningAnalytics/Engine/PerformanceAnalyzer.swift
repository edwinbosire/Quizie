import Foundation

nonisolated protocol PerformanceAnalyzing: Sendable {
    func analyze(questionAttempts: [QuestionAttemptSnapshot], flashcardReviews: [FlashcardReviewEventSnapshot], examAttempts: [LearningExamAttemptSnapshot], taxonomy: ConceptTaxonomy, referenceDate: Date) -> LearnerPerformanceReport
}

nonisolated struct TrendAnalyzer: Sendable {
    let configuration: AnalyticsConfiguration
    private let mastery = MasteryCalculator()

    init(configuration: AnalyticsConfiguration = .v1) { self.configuration = configuration }

    func trend(for evidence: [LearningEvidence]) -> PerformanceTrend {
        let sorted = evidence.sorted { $0.occurredAt < $1.occurredAt }
        let recent = Array(sorted.suffix(configuration.trendWindowSize))
        let priorEnd = max(0, sorted.count - recent.count)
        let previous = Array(sorted.prefix(priorEnd).suffix(configuration.trendWindowSize))
        guard recent.count >= configuration.minimumTrendWindowCount, previous.count >= configuration.minimumTrendWindowCount,
              let recentMastery = mastery.mastery(for: recent), let previousMastery = mastery.mastery(for: previous) else { return .unknown }
        let delta = recentMastery - previousMastery
        if delta >= configuration.trendThreshold { return .improving }
        if delta <= -configuration.trendThreshold { return .declining }
        return .stable
    }
}

nonisolated struct ForgettingAnalyzer: Sendable {
    let configuration: AnalyticsConfiguration
    private let mastery = MasteryCalculator()

    init(configuration: AnalyticsConfiguration = .v1) { self.configuration = configuration }

    func risk(for evidence: [LearningEvidence]) -> ForgettingRisk {
        let sorted = evidence.sorted { $0.occurredAt < $1.occurredAt }
        let recent = Array(sorted.suffix(configuration.trendWindowSize))
        let history = Array(sorted.dropLast(recent.count))
        guard recent.count >= configuration.minimumForgettingWindowCount,
              history.count >= configuration.minimumForgettingWindowCount,
              let historicalMastery = mastery.mastery(for: history), historicalMastery >= configuration.previouslyMasteredThreshold,
              let recentMastery = mastery.mastery(for: recent) else { return .unknown }
        switch historicalMastery - recentMastery {
        case ..<0.10: return .none
        case ..<0.20: return .low
        case ..<0.30: return .medium
        default: return .high
        }
    }
}

nonisolated struct SourceMismatchAnalyzer: Sendable {
    let configuration: AnalyticsConfiguration

    init(configuration: AnalyticsConfiguration = .v1) { self.configuration = configuration }

    func mismatch(examMastery: Double?, examConfidence: Double, flashcardMastery: Double?, flashcardConfidence: Double) -> SourcePerformanceMismatch {
        guard examConfidence >= configuration.sufficientConfidence, flashcardConfidence >= configuration.sufficientConfidence,
              let examMastery, let flashcardMastery, abs(examMastery - flashcardMastery) >= configuration.mismatchThreshold else { return .none }
        return examMastery < flashcardMastery ? .examWeakFlashcardStrong : .examStrongFlashcardWeak
    }
}

nonisolated struct RevisionPriorityCalculator: Sendable {
    let configuration: AnalyticsConfiguration

    init(configuration: AnalyticsConfiguration = .v1) { self.configuration = configuration }

    func priority(mastery: Double?, confidence: Double, importance: Double, trend: PerformanceTrend, forgettingRisk: ForgettingRisk) -> Double? {
        guard let mastery, confidence >= configuration.sufficientConfidence else { return nil }
        let trendFactor: Double = switch trend {
        case .declining: configuration.decliningPriorityFactor
        case .improving: configuration.improvingPriorityFactor
        case .stable, .unknown: 1
        }
        let forgettingFactor: Double = switch forgettingRisk {
        case .low: configuration.lowForgettingFactor
        case .medium: configuration.mediumForgettingFactor
        case .high: configuration.highForgettingFactor
        case .none, .unknown: 1
        }
        return min(max((1 - mastery) * confidence * importance * trendFactor * forgettingFactor, 0), 1)
    }
}

nonisolated struct RevisionRecommendationEngine: Sendable {
    let configuration: AnalyticsConfiguration

    init(configuration: AnalyticsConfiguration = .v1) { self.configuration = configuration }

    func recommendations(for concepts: [ConceptPerformance]) -> [RevisionRecommendation] {
        concepts.compactMap { concept in
            let reason: RecommendationReason
            let actions: [RecommendedAction]
            if concept.confidence < configuration.sufficientConfidence {
                guard concept.evidenceCount > 0 else { return nil }
                reason = .insufficientCoverage
                actions = [.practiceQuestions, .takeMiniQuiz]
            } else if concept.mismatch == .examWeakFlashcardStrong {
                reason = .examFlashcardMismatch
                actions = [.practiceQuestions, .takeMiniQuiz]
            } else if concept.mismatch == .examStrongFlashcardWeak {
                reason = .examFlashcardMismatch
                actions = [.reviewFlashcards]
            } else if [.medium, .high].contains(concept.forgettingRisk) {
                reason = .forgetting
                actions = [.readHandbook, .reviewFlashcards, .practiceQuestions]
            } else if concept.trend == .declining {
                reason = .decliningPerformance
                actions = [.readHandbook, .practiceQuestions]
            } else if let mastery = concept.mastery, mastery < 0.60 {
                reason = .lowMastery
                actions = [.readHandbook, .reviewFlashcards, .practiceQuestions]
            } else {
                return nil
            }
            return RevisionRecommendation(id: deterministicID(concept.id, reason: reason), conceptID: concept.id, priority: concept.revisionPriority ?? 0.05, reason: reason, actions: actions)
        }.sorted { $0.priority == $1.priority ? $0.conceptID < $1.conceptID : $0.priority > $1.priority }
    }

    private func deterministicID(_ conceptID: String, reason: RecommendationReason) -> UUID {
        var bytes = Array(repeating: UInt8(0), count: 16)
        for (index, byte) in "\(conceptID):\(reason.rawValue)".utf8.enumerated() { bytes[index % 16] = bytes[index % 16] &+ byte }
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}

nonisolated struct PerformanceAnalyzer: PerformanceAnalyzing {
    let configuration: AnalyticsConfiguration
    private let mastery = MasteryCalculator()

    init(configuration: AnalyticsConfiguration = .v1) { self.configuration = configuration }

    func analyze(questionAttempts: [QuestionAttemptSnapshot], flashcardReviews: [FlashcardReviewEventSnapshot], examAttempts: [LearningExamAttemptSnapshot], taxonomy: ConceptTaxonomy, referenceDate: Date) -> LearnerPerformanceReport {
        let evidence = EvidenceNormalizer(configuration: configuration).normalize(questionAttempts: questionAttempts, flashcardReviews: flashcardReviews, taxonomy: taxonomy, referenceDate: referenceDate)
        let evidenceByConcept = Dictionary(grouping: evidence, by: \.conceptID)
        var performances: [String: ConceptPerformance] = [:]
        var visiting = Set<String>()
        let conceptsByID = taxonomy.conceptsByID

        func performance(for concept: TaxonomyConcept) -> ConceptPerformance {
            if let existing = performances[concept.id] { return existing }
            guard visiting.insert(concept.id).inserted else { return directPerformance(concept: concept, evidence: evidenceByConcept[concept.id] ?? []) }
            defer { visiting.remove(concept.id) }
            let directEvidence = evidenceByConcept[concept.id] ?? []
            let value: ConceptPerformance
            if directEvidence.isEmpty {
                let children = concept.childIds.compactMap { conceptsByID[$0] }.map { performance(for: $0) }
                value = aggregate(concept: concept, children: children)
            } else {
                // Direct evidence is authoritative for a parent. Child evidence is not blended into it,
                // which prevents the same descendant observation being counted at multiple levels.
                value = directPerformance(concept: concept, evidence: directEvidence)
            }
            performances[concept.id] = value
            return value
        }

        for concept in taxonomy.concepts { _ = performance(for: concept) }
        let concepts = taxonomy.concepts.compactMap { performances[$0.id] }
        let known = concepts.filter { $0.classification != .insufficientEvidence }
        let overallDenominator = known.reduce(0) { $0 + $1.importance * $1.confidence }
        let overallMastery = overallDenominator > 0 ? known.reduce(0) { $0 + ($1.mastery ?? 0) * $1.importance * $1.confidence } / overallDenominator : nil
        let overallConfidence = concepts.isEmpty ? 0 : concepts.reduce(0) { $0 + $1.confidence } / Double(concepts.count)
        let weaknesses = known.filter { ($0.mastery ?? 1) < 0.60 }.sorted(by: priorityOrder)
        let strengths = known.filter { ($0.mastery ?? 0) >= 0.75 }.sorted { ($0.mastery ?? 0) > ($1.mastery ?? 0) }
        let examAnalytics = makeExamAnalytics(examAttempts)
        let recommendations = RevisionRecommendationEngine(configuration: configuration).recommendations(for: concepts)
        return LearnerPerformanceReport(
            generatedAt: referenceDate,
            overallMastery: overallMastery,
            overallConfidence: overallConfidence,
            examAnalytics: examAnalytics,
            flashcardAnalytics: makeFlashcardAnalytics(flashcardReviews),
            concepts: concepts,
            weaknesses: weaknesses,
            strengths: strengths,
            improvingConcepts: known.filter { $0.trend == .improving }.sorted(by: priorityOrder),
            decliningConcepts: known.filter { $0.trend == .declining }.sorted(by: priorityOrder),
            forgettingRisks: known.filter { [.low, .medium, .high].contains($0.forgettingRisk) }.sorted(by: priorityOrder),
            recommendations: recommendations,
            readiness: readiness(examAnalytics: examAnalytics, overallConfidence: overallConfidence, weaknesses: weaknesses)
        )
    }

    private func directPerformance(concept: TaxonomyConcept, evidence: [LearningEvidence]) -> ConceptPerformance {
        let exam = evidence.filter { $0.source != .flashcard }
        let flashcards = evidence.filter { $0.source == .flashcard }
        let confidenceCalculator = ConfidenceCalculator(configuration: configuration)
        let confidence = confidenceCalculator.confidence(for: evidence)
        let examConfidence = confidenceCalculator.confidence(for: exam)
        let flashcardConfidence = confidenceCalculator.confidence(for: flashcards)
        let value = mastery.mastery(for: evidence)
        let trend = TrendAnalyzer(configuration: configuration).trend(for: evidence)
        let forgetting = ForgettingAnalyzer(configuration: configuration).risk(for: evidence)
        let mismatch = SourceMismatchAnalyzer(configuration: configuration).mismatch(examMastery: mastery.mastery(for: exam), examConfidence: examConfidence, flashcardMastery: mastery.mastery(for: flashcards), flashcardConfidence: flashcardConfidence)
        let priority = RevisionPriorityCalculator(configuration: configuration).priority(mastery: value, confidence: confidence, importance: concept.importance.weight, trend: trend, forgettingRisk: forgetting)
        return ConceptPerformance(id: concept.id, displayName: concept.displayName, parentID: concept.parentId, childIDs: concept.childIds, mastery: value, confidence: confidence, examMastery: mastery.mastery(for: exam), flashcardMastery: mastery.mastery(for: flashcards), examConfidence: examConfidence, flashcardConfidence: flashcardConfidence, evidenceCount: evidence.count, uniqueQuestionCount: Set(exam.map(\.sourceItemID)).count, flashcardReviewCount: flashcards.count, trend: trend, classification: classification(mastery: value, confidence: confidence), forgettingRisk: forgetting, mismatch: mismatch, revisionPriority: priority, importance: concept.importance.weight, handbookReferences: concept.handbookReferences)
    }

    private func aggregate(concept: TaxonomyConcept, children: [ConceptPerformance]) -> ConceptPerformance {
        let eligible = children.filter { $0.classification != .insufficientEvidence && $0.mastery != nil }
        let denominator = eligible.reduce(0) { $0 + $1.importance * $1.confidence }
        let value = denominator > 0 ? eligible.reduce(0) { $0 + ($1.mastery ?? 0) * $1.importance * $1.confidence } / denominator : nil
        let confidence = eligible.isEmpty ? 0 : 1 - eligible.reduce(1) { $0 * (1 - min($1.confidence * $1.importance, 0.95)) }
        let priority = RevisionPriorityCalculator(configuration: configuration).priority(mastery: value, confidence: confidence, importance: concept.importance.weight, trend: .unknown, forgettingRisk: .unknown)
        return ConceptPerformance(id: concept.id, displayName: concept.displayName, parentID: concept.parentId, childIDs: concept.childIds, mastery: value, confidence: confidence, examMastery: weightedSourceMastery(eligible, keyPath: \.examMastery, confidenceKeyPath: \.examConfidence), flashcardMastery: weightedSourceMastery(eligible, keyPath: \.flashcardMastery, confidenceKeyPath: \.flashcardConfidence), examConfidence: eligible.map(\.examConfidence).max() ?? 0, flashcardConfidence: eligible.map(\.flashcardConfidence).max() ?? 0, evidenceCount: eligible.reduce(0) { $0 + $1.evidenceCount }, uniqueQuestionCount: eligible.reduce(0) { $0 + $1.uniqueQuestionCount }, flashcardReviewCount: eligible.reduce(0) { $0 + $1.flashcardReviewCount }, trend: .unknown, classification: classification(mastery: value, confidence: confidence), forgettingRisk: .unknown, mismatch: .none, revisionPriority: priority, importance: concept.importance.weight, handbookReferences: concept.handbookReferences)
    }

    private func weightedSourceMastery(_ values: [ConceptPerformance], keyPath: KeyPath<ConceptPerformance, Double?>, confidenceKeyPath: KeyPath<ConceptPerformance, Double>) -> Double? {
        let available = values.filter { $0[keyPath: keyPath] != nil }
        let denominator = available.reduce(0) { $0 + $1[keyPath: confidenceKeyPath] * $1.importance }
        return denominator > 0 ? available.reduce(0) { $0 + ($1[keyPath: keyPath] ?? 0) * $1[keyPath: confidenceKeyPath] * $1.importance } / denominator : nil
    }

    private func classification(mastery: Double?, confidence: Double) -> MasteryClassification {
        guard confidence >= configuration.sufficientConfidence, let mastery else { return .insufficientEvidence }
        switch mastery {
        case ..<0.40: return .critical
        case ..<0.60: return .weak
        case ..<0.75: return .developing
        case ..<0.90: return .strong
        default: return .mastered
        }
    }

    private func makeExamAnalytics(_ attempts: [LearningExamAttemptSnapshot]) -> ExamAnalytics {
        let completed = attempts.filter(\.isCompleted).sorted { ($0.completedAt ?? $0.startedAt) > ($1.completedAt ?? $1.startedAt) }
        let scores = completed.map { $0.totalCount > 0 ? Double($0.correctCount) / Double($0.totalCount) : 0 }
        let recent = Array(scores.prefix(configuration.recentExamCount))
        let passCount = completed.filter { $0.passed == true }.count
        let streak = completed.prefix { $0.passed == true }.count
        let durations = completed.compactMap(\.duration)
        let recentTrend: PerformanceTrend
        if scores.count >= 4 {
            let split = min(3, scores.count / 2)
            let current = scores.prefix(split).reduce(0, +) / Double(split)
            let previous = scores.dropFirst(split).prefix(split).reduce(0, +) / Double(split)
            let delta = current - previous
            recentTrend = delta >= configuration.trendThreshold ? .improving : delta <= -configuration.trendThreshold ? .declining : .stable
        } else { recentTrend = .unknown }
        return ExamAnalytics(examCount: attempts.count, completedExamCount: completed.count, passCount: passCount, passRate: completed.isEmpty ? nil : Double(passCount) / Double(completed.count), lifetimeAverage: scores.isEmpty ? nil : scores.reduce(0, +) / Double(scores.count), recentAverage: recent.isEmpty ? nil : recent.reduce(0, +) / Double(recent.count), bestScore: scores.max(), currentPassStreak: streak, averageDuration: durations.isEmpty ? nil : durations.reduce(0, +) / Double(durations.count), recentScoreTrend: recentTrend)
    }

    private func makeFlashcardAnalytics(_ reviews: [FlashcardReviewEventSnapshot]) -> FlashcardAnalytics {
        let recent = reviews.sorted { $0.reviewedAt > $1.reviewedAt }.prefix(20).map { configuration.flashcardScore($0.rating) }
        return FlashcardAnalytics(reviewCount: reviews.count, uniqueCardCount: Set(reviews.map(\.flashcardID)).count, recentAverage: recent.isEmpty ? nil : recent.reduce(0, +) / Double(recent.count))
    }

    private func readiness(examAnalytics: ExamAnalytics, overallConfidence: Double, weaknesses: [ConceptPerformance]) -> ExamReadiness {
        guard examAnalytics.completedExamCount >= 3, overallConfidence >= 0.20, let recent = examAnalytics.recentAverage, let passRate = examAnalytics.passRate else { return .notEnoughData }
        if weaknesses.contains(where: { $0.classification == .critical }) || recent < 0.60 { return .needsSignificantRevision }
        if recent < 0.70 || passRate < 0.60 { return .progressing }
        if recent < 0.75 || passRate < 0.75 { return .approachingReadiness }
        if examAnalytics.completedExamCount >= 5, recent >= 0.85, passRate >= 0.90, weaknesses.isEmpty { return .consistentlyStrong }
        return .likelyReady
    }

    private func priorityOrder(_ left: ConceptPerformance, _ right: ConceptPerformance) -> Bool {
        (left.revisionPriority ?? 0) == (right.revisionPriority ?? 0) ? left.id < right.id : (left.revisionPriority ?? 0) > (right.revisionPriority ?? 0)
    }
}
