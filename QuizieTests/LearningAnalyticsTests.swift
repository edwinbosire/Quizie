import Foundation
import Testing
@testable import BritReady__Life_in_UK_Test

@MainActor
struct LearningAnalyticsTests {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    @Test("Correct and incorrect answers move mastery in the expected direction")
    func questionScoresChangeMastery() throws {
        let taxonomy = fixtureTaxonomy()
        let wrong = question(id: "wrong", correct: false)
        let correct = question(id: "correct", correct: true, secondsAgo: -1)
        let analyzer = PerformanceAnalyzer()
        let before = try #require(concept("leaf-a", in: analyzer.analyze(questionAttempts: [wrong], flashcardReviews: [], examAttempts: [], taxonomy: taxonomy, referenceDate: now)).mastery)
        let after = try #require(concept("leaf-a", in: analyzer.analyze(questionAttempts: [wrong, correct], flashcardReviews: [], examAttempts: [], taxonomy: taxonomy, referenceDate: now)).mastery)
        #expect(before == 0)
        #expect(after > before)
        #expect((0...1).contains(after))
    }

    @Test("Hard questions carry more weight than easy questions")
    func difficultyWeighting() throws {
        let report = analyze(questions: [question(id: "hard", correct: true, difficulty: .hard), question(id: "easy", correct: false, difficulty: .easy)])
        #expect(try #require(concept("leaf-a", in: report).mastery) > 0.5)
    }

    @Test("Flashcard evidence carries less weight than mock exam evidence")
    func sourceWeighting() throws {
        let report = analyze(questions: [question(id: "exam", correct: true)], flashcards: reviews(cardPrefix: "card", ratings: [.again]))
        #expect(try #require(concept("leaf-a", in: report).mastery) > 0.5)
    }

    @Test("Recent evidence outweighs old evidence")
    func recencyWeighting() throws {
        let oldWrong = question(id: "old", correct: false, secondsAgo: 180 * 86_400)
        let recentCorrect = question(id: "recent", correct: true)
        #expect(try #require(concept("leaf-a", in: analyze(questions: [oldWrong, recentCorrect])).mastery) > 0.85)
    }

    @Test("Repeated questions are discounted")
    func repeatedQuestionDiscounting() throws {
        let repeated = [question(id: "same", correct: false), question(id: "same", correct: true, secondsAgo: -1)]
        let unique = [question(id: "first", correct: false), question(id: "second", correct: true, secondsAgo: -1)]
        let repeatedMastery = try #require(concept("leaf-a", in: analyze(questions: repeated)).mastery)
        let uniqueMastery = try #require(concept("leaf-a", in: analyze(questions: unique)).mastery)
        #expect(repeatedMastery < uniqueMastery)
    }

    @Test("Confidence requires unique evidence")
    func confidenceUsesUniqueItems() throws {
        let one = analyze(questions: [question(id: "one", correct: true)])
        let many = analyze(questions: (0..<5).map { question(id: "q\($0)", correct: true, secondsAgo: -Double($0)) })
        #expect(concept("leaf-a", in: one).classification == .insufficientEvidence)
        #expect(concept("leaf-a", in: one).confidence < concept("leaf-a", in: many).confidence)
        #expect(concept("leaf-a", in: many).classification == .mastered)
    }

    @Test("Exam, flashcard, and combined mastery remain separate")
    func sourceSpecificMastery() throws {
        let questions = (0..<4).map { question(id: "q\($0)", correct: false, secondsAgo: -Double($0)) }
        let report = analyze(questions: questions, flashcards: reviews(cardPrefix: "c", ratings: [.easy, .easy, .easy, .easy]))
        let value = concept("leaf-a", in: report)
        #expect(value.examMastery == 0)
        #expect(value.flashcardMastery == 1)
        #expect(try #require(value.mastery) > 0 && value.mastery! < 1)
    }

    @Test("Parent mastery aggregates known children without treating unknown children as zero")
    func hierarchyAggregation() throws {
        let questions = (0..<4).map { question(id: "a\($0)", correct: true, conceptID: "leaf-a", secondsAgo: -Double($0)) }
        let report = analyze(questions: questions)
        let parent = concept("parent", in: report)
        #expect(parent.mastery == 1)
        #expect(parent.classification == .mastered)
        #expect(concept("leaf-b", in: report).mastery == nil)
    }

    @Test("Direct parent evidence is not double counted with child evidence")
    func hierarchyDoesNotDoubleCount() throws {
        let parentEvidence = (0..<4).map { question(id: "p\($0)", correct: false, conceptID: "parent", secondsAgo: -Double($0)) }
        let childEvidence = (0..<4).map { question(id: "a\($0)", correct: true, conceptID: "leaf-a", secondsAgo: -Double($0)) }
        let report = analyze(questions: parentEvidence + childEvidence)
        #expect(concept("parent", in: report).mastery == 0)
    }

    @Test("Improving, declining, stable, and insufficient trends are deterministic")
    func trends() {
        let historicalBad = (0..<10).map { question(id: "hb\($0)", correct: false, secondsAgo: Double(30 - $0)) }
        let recentGood = (0..<10).map { question(id: "rg\($0)", correct: true, secondsAgo: Double(10 - $0)) }
        #expect(concept("leaf-a", in: analyze(questions: historicalBad + recentGood)).trend == .improving)
        let historicalGood = (0..<10).map { question(id: "hg\($0)", correct: true, secondsAgo: Double(30 - $0)) }
        let recentBad = (0..<10).map { question(id: "rb\($0)", correct: false, secondsAgo: Double(10 - $0)) }
        #expect(concept("leaf-a", in: analyze(questions: historicalGood + recentBad)).trend == .declining)
        let mixed = (0..<20).map { question(id: "m\($0)", correct: $0.isMultiple(of: 2), secondsAgo: Double(20 - $0)) }
        #expect(concept("leaf-a", in: analyze(questions: mixed)).trend == .stable)
        #expect(concept("leaf-a", in: analyze(questions: Array(mixed.prefix(3)))).trend == .unknown)
    }

    @Test("Forgetting requires prior mastery")
    func forgetting() {
        let historicalGood = (0..<10).map { question(id: "old\($0)", correct: true, secondsAgo: Double(30 + 10 - $0)) }
        let recent = (0..<10).map { question(id: "new\($0)", correct: $0 < 4, secondsAgo: Double(10 - $0)) }
        #expect(concept("leaf-a", in: analyze(questions: historicalGood + recent)).forgettingRisk == .high)
        let historicalBad = historicalGood.map { replacement($0, correct: false) }
        #expect(concept("leaf-a", in: analyze(questions: historicalBad + recent)).forgettingRisk == .unknown)
    }

    @Test("Source mismatch requires confidence from both sources")
    func sourceMismatch() {
        let weakExam = (0..<4).map { question(id: "q\($0)", correct: false, secondsAgo: -Double($0)) }
        let strongCards = reviews(cardPrefix: "card", ratings: [.easy, .easy, .easy, .easy])
        #expect(concept("leaf-a", in: analyze(questions: weakExam, flashcards: strongCards)).mismatch == .examWeakFlashcardStrong)
        let strongExam = weakExam.map { replacement($0, correct: true) }
        let weakCards = reviews(cardPrefix: "weak", ratings: [.again, .again, .again, .again])
        #expect(concept("leaf-a", in: analyze(questions: strongExam, flashcards: weakCards)).mismatch == .examStrongFlashcardWeak)
        #expect(concept("leaf-a", in: analyze(questions: [weakExam[0]], flashcards: [strongCards[0]])).mismatch == .none)
    }

    @Test("Important weak concepts rank above equally weak low-importance concepts")
    func weaknessPriority() {
        let a = (0..<5).map { question(id: "a\($0)", correct: false, conceptID: "leaf-a", secondsAgo: -Double($0)) }
        let b = (0..<5).map { question(id: "b\($0)", correct: false, conceptID: "leaf-b", secondsAgo: -Double($0)) }
        let report = analyze(questions: a + b)
        #expect((concept("leaf-a", in: report).revisionPriority ?? 0) > (concept("leaf-b", in: report).revisionPriority ?? 0))
    }

    @Test("Recommendations respond to mismatch and joint weakness")
    func recommendations() throws {
        let weakExam = (0..<4).map { question(id: "q\($0)", correct: false, secondsAgo: -Double($0)) }
        let strongCards = reviews(cardPrefix: "card", ratings: [.easy, .easy, .easy, .easy])
        let mismatch = try #require(analyze(questions: weakExam, flashcards: strongCards).recommendations.first { $0.conceptID == "leaf-a" })
        #expect(mismatch.actions.contains(.practiceQuestions))
        let weakCards = reviews(cardPrefix: "weak", ratings: [.again, .again, .again, .again])
        let jointlyWeak = try #require(analyze(questions: weakExam, flashcards: weakCards).recommendations.first { $0.conceptID == "leaf-a" })
        #expect(jointlyWeak.actions == [.readHandbook, .reviewFlashcards, .practiceQuestions])
        let insufficient = try #require(analyze(questions: [question(id: "single", correct: true)]).recommendations.first { $0.conceptID == "leaf-a" })
        #expect(insufficient.reason == .insufficientCoverage)
        #expect(insufficient.actions == [.readHandbook, .practiceQuestions, .takeMiniQuiz])
    }

    @Test("Duplicate and out-of-order events do not change the report")
    func duplicateEvents() throws {
        let value = question(id: "q", correct: true)
        let evidence = EvidenceNormalizer().normalize(questionAttempts: [value, value], flashcardReviews: [], taxonomy: fixtureTaxonomy(), referenceDate: now)
        #expect(evidence.count == 1)
    }

    @Test("Unknown concept IDs are ignored and replacements remain usable")
    func taxonomyMigration() {
        let unknown = question(id: "q", correct: true, conceptID: "retired")
        #expect(EvidenceNormalizer().normalize(questionAttempts: [unknown], flashcardReviews: [], taxonomy: fixtureTaxonomy(), referenceDate: now).isEmpty)
        var config = AnalyticsConfiguration.v1
        config.conceptIDReplacements = ["retired": "leaf-a"]
        #expect(EvidenceNormalizer(configuration: config).normalize(questionAttempts: [unknown], flashcardReviews: [], taxonomy: fixtureTaxonomy(), referenceDate: now).first?.conceptID == "leaf-a")
    }

    @Test("Abandoned exams count as exams but not completed exams")
    func abandonedExamAnalytics() {
        let exam = LearningExamAttemptSnapshot(id: UUID(), startedAt: now, completedAt: nil, questionAttemptIDs: [], correctCount: 0, totalCount: 24, passed: nil, duration: nil, didTimeOut: false, testID: nil)
        let analytics = PerformanceAnalyzer().analyze(questionAttempts: [], flashcardReviews: [], examAttempts: [exam], taxonomy: fixtureTaxonomy(), referenceDate: now).examAnalytics
        #expect(analytics.examCount == 1)
        #expect(analytics.completedExamCount == 0)
    }

    @Test("Improving exam fixtures emphasize recent performance")
    func improvingExamScenario() {
        let scores = [0.52, 0.61, 0.68, 0.76, 0.84]
        let exams = scores.enumerated().map { index, score in exam(score: score, daysAgo: 5 - index) }
        let analytics = PerformanceAnalyzer().analyze(questionAttempts: [], flashcardReviews: [], examAttempts: exams, taxonomy: fixtureTaxonomy(), referenceDate: now).examAnalytics
        #expect(analytics.recentAverage! >= analytics.lifetimeAverage!)
        #expect(analytics.recentScoreTrend == .improving)
    }

    @Test("Quiz engine persists submitted question evidence and completes its learning exam")
    func quizCaptureIntegration() throws {
        let store = InMemoryLearningEventStore()
        let issues = PersistenceIssueCenter()
        let history = LearningEventHistory(store: store, issues: issues)
        let engine = QuizEngine(configuration: .custom(questionCount: 1, timeLimitSeconds: 60, passMarkCount: 1), questionRepository: InMemoryQuestionRepository([quizQuestion(id: "q1")]), learningEvents: history, clock: AnalyticsTestClock(now), scheduler: AnalyticsTestScheduler())
        engine.startExam()
        engine.toggleChoice(0, isMultiSelect: false)
        engine.submitAndAdvance()
        #expect(history.questionAttempts.count == 1)
        #expect(history.questionAttempts.first?.conceptWeights.first?.conceptID == "leaf-a")
        #expect(history.examAttempts.first?.completedAt == nil)
        engine.manualAdvance()
        #expect(history.examAttempts.first?.completedAt == now)
        #expect(history.examAttempts.first?.questionAttemptIDs.count == 1)
    }

    @Test("Abandoning a quiz retains completed answers without completing the exam")
    func partialQuizCapture() {
        let store = InMemoryLearningEventStore()
        let issues = PersistenceIssueCenter()
        let history = LearningEventHistory(store: store, issues: issues)
        let questions = [quizQuestion(id: "q1"), quizQuestion(id: "q2")]
        let engine = QuizEngine(configuration: .custom(questionCount: 2, timeLimitSeconds: 60, passMarkCount: 2), questionRepository: InMemoryQuestionRepository(questions), learningEvents: history, clock: AnalyticsTestClock(now), scheduler: AnalyticsTestScheduler())
        engine.startExam()
        engine.toggleChoice(0, isMultiSelect: false)
        engine.submitAndAdvance()
        engine.returnToLobby()
        #expect(history.questionAttempts.count == 1)
        #expect(history.examAttempts.first?.completedAt == nil)
        #expect(history.examAttempts.first?.questionAttemptIDs.count == 1)
    }

    @Test("Every flashcard rating appends a historical review event")
    func flashcardCaptureIntegration() {
        let eventStore = InMemoryLearningEventStore()
        let issues = PersistenceIssueCenter()
        let history = LearningEventHistory(store: eventStore, issues: issues)
        let memory = FlashcardMemory(store: InMemoryFlashcardMemoryStore(), issues: issues, learningEvents: history)
        let card = Flashcard(id: "card", prompt: "Prompt", answer: "Answer", topic: "Test", taxonomy: ContentTaxonomyTags(conceptIds: ["leaf-a"]))
        memory.record(.learning, for: card, at: now)
        memory.record(.known, for: card, at: now.addingTimeInterval(60))
        #expect(history.flashcardReviews.count == 2)
        #expect(history.flashcardReviews.map(\.rating) == [.again, .good])
    }

    @Test("Cached reports invalidate across algorithm and taxonomy versions")
    func snapshotInvalidation() throws {
        let cache = InMemoryPerformanceSnapshotStore()
        let report = LearnerPerformanceReport.empty(at: now)
        try cache.save(report, taxonomyVersion: "v1", eventRevision: 4)
        #expect(try cache.load(algorithmVersion: performanceAlgorithmVersion, taxonomyVersion: "v1")?.eventRevision == 4)
        #expect(try cache.load(algorithmVersion: performanceAlgorithmVersion + 1, taxonomyVersion: "v1") == nil)
        #expect(try cache.load(algorithmVersion: performanceAlgorithmVersion, taxonomyVersion: "v2") == nil)
    }

    private func analyze(questions: [QuestionAttemptSnapshot] = [], flashcards: [FlashcardReviewEventSnapshot] = []) -> LearnerPerformanceReport {
        PerformanceAnalyzer().analyze(questionAttempts: questions, flashcardReviews: flashcards, examAttempts: [], taxonomy: fixtureTaxonomy(), referenceDate: now)
    }

    private func concept(_ id: String, in report: LearnerPerformanceReport) -> ConceptPerformance {
        report.concepts.first { $0.id == id }!
    }

    private func question(id: String, correct: Bool, conceptID: String = "leaf-a", difficulty: QuestionDifficulty = .medium, secondsAgo: Double = 0) -> QuestionAttemptSnapshot {
        QuestionAttemptSnapshot(questionID: id, examAttemptID: nil, conceptWeights: [ConceptEvidenceWeight(conceptID: conceptID, weight: 1)], selectedAnswerIDs: [correct ? "right" : "wrong"], correctAnswerIDs: ["right"], wasCorrect: correct, difficulty: difficulty, responseTime: 10, answeredAt: now.addingTimeInterval(-secondsAgo), source: .mockExam)
    }

    private func reviews(cardPrefix: String, ratings: [FlashcardRating]) -> [FlashcardReviewEventSnapshot] {
        ratings.enumerated().map { index, rating in FlashcardReviewEventSnapshot(flashcardID: "\(cardPrefix)-\(index)", conceptIDs: ["leaf-a"], rating: rating, reviewedAt: now.addingTimeInterval(Double(index))) }
    }

    private func shifted(_ value: QuestionAttemptSnapshot, by seconds: TimeInterval) -> QuestionAttemptSnapshot {
        QuestionAttemptSnapshot(id: value.id, questionID: value.questionID, examAttemptID: value.examAttemptID, conceptWeights: value.conceptWeights, selectedAnswerIDs: value.selectedAnswerIDs, correctAnswerIDs: value.correctAnswerIDs, wasCorrect: value.wasCorrect, difficulty: value.difficulty, responseTime: value.responseTime, answeredAt: value.answeredAt.addingTimeInterval(seconds), source: value.source)
    }

    private func replacement(_ value: QuestionAttemptSnapshot, correct: Bool) -> QuestionAttemptSnapshot {
        QuestionAttemptSnapshot(id: value.id, questionID: value.questionID, examAttemptID: value.examAttemptID, conceptWeights: value.conceptWeights, selectedAnswerIDs: [correct ? "right" : "wrong"], correctAnswerIDs: ["right"], wasCorrect: correct, difficulty: value.difficulty, responseTime: value.responseTime, answeredAt: value.answeredAt, source: value.source)
    }

    private func exam(score: Double, daysAgo: Int) -> LearningExamAttemptSnapshot {
        let date = now.addingTimeInterval(-Double(daysAgo) * 86_400)
        return LearningExamAttemptSnapshot(id: UUID(), startedAt: date.addingTimeInterval(-1_000), completedAt: date, questionAttemptIDs: [], correctCount: Int((score * 100).rounded()), totalCount: 100, passed: score >= 0.75, duration: 1_000, didTimeOut: false, testID: nil)
    }

    private func quizQuestion(id: String) -> QuizQuestion {
        QuizQuestion(id: id, question: "Question?", choices: ["Right", "Wrong"], correctIndices: [0], isMultiSelect: false, year: "", category: 1, explanationLink: "", taxonomy: ContentTaxonomyTags(conceptIds: ["leaf-a"]))
    }

    private func fixtureTaxonomy() -> ConceptTaxonomy {
        let parent = taxonomyConcept(id: "parent", name: "Parliament", parentID: nil, children: ["leaf-a", "leaf-b"], importance: 1)
        let leafA = taxonomyConcept(id: "leaf-a", name: "Commons", parentID: "parent", importance: 0.9)
        let leafB = taxonomyConcept(id: "leaf-b", name: "Lords", parentID: "parent", importance: 0.2)
        return ConceptTaxonomy(schemaVersion: 1, taxonomyVersion: "test", handbookVersion: "test", generatedAt: "", concepts: [parent, leafA, leafB], entities: [])
    }

    private func taxonomyConcept(id: String, name: String, parentID: String?, children: [String] = [], importance: Double) -> TaxonomyConcept {
        TaxonomyConcept(id: id, slug: id, displayName: name, description: "", domainId: "test", parentId: parentID, childIds: children, aliases: [], relatedConceptIds: [], handbookReferences: [], entityIds: [], importance: ConceptImportance(weight: importance, tier: importance >= 0.9 ? .critical : importance >= 0.7 ? .high : .low, rationale: "test"), taggingHints: nil)
    }
}

@MainActor
private final class AnalyticsTestClock: QuizClock {
    let now: Date
    init(_ now: Date) { self.now = now }
}

@MainActor
private final class AnalyticsTestScheduler: QuizScheduler {
    func schedule(after delay: TimeInterval, action: @escaping @MainActor () -> Void) -> QuizCancellation { QuizCancellation {} }
    func scheduleRepeating(every interval: TimeInterval, action: @escaping @MainActor () -> Void) -> QuizCancellation { QuizCancellation {} }
}
