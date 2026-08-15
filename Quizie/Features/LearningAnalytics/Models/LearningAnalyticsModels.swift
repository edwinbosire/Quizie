import Foundation

nonisolated struct AnalyticsConfiguration: Sendable {
    var mockExamWeight = 1.0
    var practiceQuestionWeight = 0.9
    var flashcardWeight = 0.6
    var easyDifficultyWeight = 0.8
    var mediumDifficultyWeight = 1.0
    var hardDifficultyWeight = 1.2
    var againScore = 0.0
    var hardScore = 0.4
    var goodScore = 0.8
    var easyScore = 1.0
    var recencyDecayLambda = 0.012792139405522477
    var repetitionWeights = [1.0, 0.7, 0.5, 0.35]
    var confidenceK = 0.20
    var sufficientConfidence = 0.45
    var trendWindowSize = 10
    var minimumTrendWindowCount = 3
    var trendThreshold = 0.10
    var minimumForgettingWindowCount = 3
    var previouslyMasteredThreshold = 0.75
    var mismatchThreshold = 0.20
    var decliningPriorityFactor = 1.25
    var improvingPriorityFactor = 0.8
    var lowForgettingFactor = 1.1
    var mediumForgettingFactor = 1.25
    var highForgettingFactor = 1.5
    var recentExamCount = 5
    var conceptIDReplacements: [String: String] = [:]

    static let v1 = AnalyticsConfiguration()

    func sourceWeight(_ source: EvidenceSource) -> Double {
        switch source {
        case .mockExam: mockExamWeight
        case .practiceQuestion: practiceQuestionWeight
        case .flashcard: flashcardWeight
        }
    }

    func difficultyWeight(_ difficulty: QuestionDifficulty) -> Double {
        switch difficulty {
        case .easy: easyDifficultyWeight
        case .medium: mediumDifficultyWeight
        case .hard: hardDifficultyWeight
        }
    }

    func flashcardScore(_ rating: FlashcardRating) -> Double {
        switch rating.analyticsScoreKey {
        case .again, .learning: againScore
        case .hard: hardScore
        case .good, .known: goodScore
        case .easy: easyScore
        }
    }

    func repetitionWeight(at index: Int) -> Double {
        repetitionWeights.indices.contains(index) ? repetitionWeights[index] : repetitionWeights.last ?? 0.35
    }
}

nonisolated struct LearningEvidence: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let conceptID: String
    let source: EvidenceSource
    let score: Double
    let sourceWeight: Double
    let conceptWeight: Double
    let difficultyWeight: Double
    let recencyWeight: Double
    let repetitionWeight: Double
    let effectiveWeight: Double
    let sourceItemID: String
    let occurredAt: Date
}

nonisolated enum MasteryClassification: String, Codable, Sendable {
    case insufficientEvidence
    case critical
    case weak
    case developing
    case strong
    case mastered
}

nonisolated enum PerformanceTrend: String, Codable, Sendable {
    case improving
    case stable
    case declining
    case unknown
}

nonisolated enum ForgettingRisk: String, Codable, Sendable {
    case none
    case low
    case medium
    case high
    case unknown
}

nonisolated enum SourcePerformanceMismatch: String, Codable, Sendable {
    case none
    case examWeakFlashcardStrong
    case examStrongFlashcardWeak
}

nonisolated struct ConceptPerformance: Identifiable, Codable, Sendable {
    let id: String
    let displayName: String
    let parentID: String?
    let childIDs: [String]
    let mastery: Double?
    let confidence: Double
    let examMastery: Double?
    let flashcardMastery: Double?
    let examConfidence: Double
    let flashcardConfidence: Double
    let evidenceCount: Int
    let uniqueQuestionCount: Int
    let flashcardReviewCount: Int
    let trend: PerformanceTrend
    let classification: MasteryClassification
    let forgettingRisk: ForgettingRisk
    let mismatch: SourcePerformanceMismatch
    let revisionPriority: Double?
    let importance: Double
    let handbookReferences: [TaxonomyHandbookReference]
}

nonisolated enum RecommendationReason: String, Codable, Sendable {
    case lowMastery
    case decliningPerformance
    case forgetting
    case examFlashcardMismatch
    case insufficientCoverage
}

nonisolated enum RecommendedAction: String, Codable, Sendable {
    case readHandbook
    case reviewFlashcards
    case practiceQuestions
    case takeMiniQuiz
}

nonisolated struct RevisionRecommendation: Identifiable, Codable, Sendable {
    let id: UUID
    let conceptID: String
    let priority: Double
    let reason: RecommendationReason
    let actions: [RecommendedAction]
}

nonisolated struct ExamAnalytics: Codable, Sendable {
    let examCount: Int
    let completedExamCount: Int
    let passCount: Int
    let passRate: Double?
    let lifetimeAverage: Double?
    let recentAverage: Double?
    let bestScore: Double?
    let currentPassStreak: Int
    let averageDuration: TimeInterval?
    let recentScoreTrend: PerformanceTrend
}

nonisolated struct FlashcardAnalytics: Codable, Sendable {
    let reviewCount: Int
    let uniqueCardCount: Int
    let recentAverage: Double?
}

nonisolated enum ExamReadiness: String, Codable, Sendable {
    case notEnoughData
    case needsSignificantRevision
    case progressing
    case approachingReadiness
    case likelyReady
    case consistentlyStrong
}

nonisolated struct LearnerPerformanceReport: Codable, Sendable {
    let generatedAt: Date
    let overallMastery: Double?
    let overallConfidence: Double
    let examAnalytics: ExamAnalytics
    let flashcardAnalytics: FlashcardAnalytics
    let concepts: [ConceptPerformance]
    let weaknesses: [ConceptPerformance]
    let strengths: [ConceptPerformance]
    let improvingConcepts: [ConceptPerformance]
    let decliningConcepts: [ConceptPerformance]
    let forgettingRisks: [ConceptPerformance]
    let recommendations: [RevisionRecommendation]
    let readiness: ExamReadiness

    static func empty(at date: Date) -> LearnerPerformanceReport {
        LearnerPerformanceReport(generatedAt: date, overallMastery: nil, overallConfidence: 0, examAnalytics: ExamAnalytics(examCount: 0, completedExamCount: 0, passCount: 0, passRate: nil, lifetimeAverage: nil, recentAverage: nil, bestScore: nil, currentPassStreak: 0, averageDuration: nil, recentScoreTrend: .unknown), flashcardAnalytics: FlashcardAnalytics(reviewCount: 0, uniqueCardCount: 0, recentAverage: nil), concepts: [], weaknesses: [], strengths: [], improvingConcepts: [], decliningConcepts: [], forgettingRisks: [], recommendations: [], readiness: .notEnoughData)
    }
}

nonisolated let performanceAlgorithmVersion = 1
