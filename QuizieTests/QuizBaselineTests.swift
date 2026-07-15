import Foundation
import SwiftData
import Testing
@testable import Quizie

@MainActor
struct QuizScoringTests {
    @Test("Score counts only exact correct answers")
    func scoreCountsCorrectAnswers() {
        let questions = TestFixtures.questions(count: 3)
        var session = ExamSession(questions: questions, startedAt: TestFixtures.startDate)

        session.submit(answer: [0], for: questions[0])
        session.submit(answer: [1], for: questions[1])
        session.submit(answer: [0], for: questions[2])

        #expect(session.score == 2)
        #expect(session.answeredCount == 3)
        #expect(abs(session.percentage - (200.0 / 3.0)) < 0.000_001)
    }

    @Test("Pass threshold is inclusive", arguments: [17, 18, 19])
    func passThreshold(score: Int) {
        let configuration = QuizConfiguration.practice
        let questions = TestFixtures.questions(count: configuration.questionCount)
        var session = ExamSession(configuration: configuration, questions: questions, startedAt: TestFixtures.startDate)

        for question in questions.prefix(score) {
            session.submit(answer: question.correctIndices, for: question)
        }

        #expect(session.score == score)
        #expect(session.passed == (score >= configuration.passMarkCount))
    }

    @Test("Multi-select requires the complete exact selection")
    func multiSelectUsesExactSetEquality() {
        let question = TestFixtures.question(id: "multi", correctIndices: [0, 2])
        var session = ExamSession(questions: [question], startedAt: TestFixtures.startDate)

        session.submit(answer: [0], for: question)
        #expect(session.answers[question.id]?.isCorrect == false)

        session.submit(answer: [0, 1, 2], for: question)
        #expect(session.answers[question.id]?.isCorrect == false)

        session.submit(answer: [2, 0], for: question)
        #expect(session.answers[question.id]?.isCorrect == true)
        #expect(session.score == 1)
    }

    @Test("Seeded question sets are repeatable")
    func seededQuestionSetIsDeterministic() throws {
        let repository = InMemoryQuestionRepository(TestFixtures.questions(count: 10))

        let first = try repository.questions(count: 5, seed: "practice-test-4").map(\.id)
        let second = try repository.questions(count: 5, seed: "practice-test-4").map(\.id)

        #expect(first == ["q-2", "q-7", "q-0", "q-3", "q-4"])
        #expect(second == first)
    }
}

@MainActor
struct QuizConfigurationTests {
    private let customConfiguration = QuizConfiguration.custom(
        questionCount: 4,
        timeLimitSeconds: 90,
        passMarkCount: 3
    )

    @Test("A score immediately below the configured pass mark fails")
    func scoreBelowPassMarkFails() {
        var session = ExamSession(
            configuration: customConfiguration,
            questions: TestFixtures.questions(count: 4),
            startedAt: TestFixtures.startDate
        )

        for question in session.questions.prefix(2) {
            session.submit(answer: question.correctIndices, for: question)
        }

        #expect(session.score == 2)
        #expect(!session.passed)
    }

    @Test("A score equal to the configured pass mark passes")
    func scoreAtPassMarkPasses() {
        var session = ExamSession(
            configuration: customConfiguration,
            questions: TestFixtures.questions(count: 4),
            startedAt: TestFixtures.startDate
        )

        for question in session.questions.prefix(3) {
            session.submit(answer: question.correctIndices, for: question)
        }

        #expect(session.score == 3)
        #expect(session.passed)
    }

    @Test("Engine uses the supplied question count and duration")
    func engineUsesSuppliedConfiguration() {
        let engine = QuizEngine(
            configuration: customConfiguration,
            questionRepository: InMemoryQuestionRepository(TestFixtures.questions(count: 10)),
            clock: MutableQuizClock(now: TestFixtures.startDate)
        )

        #expect(engine.timeRemaining == 90)
        engine.startExam(testID: "custom-test")
        #expect(engine.session?.questions.count == 4)
        #expect(engine.session?.configuration == customConfiguration)
        #expect(engine.timeRemaining == 90)
        engine.stopTimer()
    }

    @Test("Configuration derives display labels from its rules")
    func derivedLabels() {
        #expect(customConfiguration.summaryLabel == "4 questions · 1 min")
        #expect(customConfiguration.passPercentage == 75)
    }
}

@MainActor
struct ProgressTests {
    @Test("Quiz progress is based on the current zero-based index")
    func quizProgressFraction() {
        var state = QuizState(configuration: .custom(questionCount: 4, timeLimitSeconds: 90, passMarkCount: 3))
        state.start(questions: TestFixtures.questions(count: 4), testID: nil, at: TestFixtures.startDate)
        #expect(state.progressFraction == 0)

        _ = state.toggleChoice(0)
        _ = state.submitCurrentAnswer()
        _ = state.advance(at: TestFixtures.startDate)
        _ = state.toggleChoice(0)
        _ = state.submitCurrentAnswer()
        _ = state.advance(at: TestFixtures.startDate)
        #expect(state.phase == .question(index: 2))
        #expect(state.progressFraction == 0.5)
    }

    @Test("Reading progress clamps scroll calculations")
    func readingProgressCalculation() {
        let progress = ReadingProgress(chapterID: "chapter_01", lastReadDate: TestFixtures.startDate)

        progress.updateProgress(
            scrollOffset: -50,
            contentHeight: 1_000,
            viewportHeight: 200,
            at: TestFixtures.laterDate
        )
        #expect(progress.progress == 0)

        progress.updateProgress(
            scrollOffset: 400,
            contentHeight: 1_000,
            viewportHeight: 200,
            at: TestFixtures.laterDate
        )
        #expect(progress.progress == 0.5)

        progress.updateProgress(
            scrollOffset: 900,
            contentHeight: 1_000,
            viewportHeight: 200,
            at: TestFixtures.laterDate
        )
        #expect(progress.progress == 1)
        #expect(progress.lastReadDate == TestFixtures.laterDate)
    }

    @Test("Overall completion averages deterministic chapter progress")
    func overallCompletion() throws {
        let store = InMemoryReadingProgressStore(records: [
            ReadingProgressSnapshot(chapterID: "chapter_01", progress: 0.25, lastReadDate: TestFixtures.startDate),
            ReadingProgressSnapshot(chapterID: "chapter_02", progress: 0.75, lastReadDate: TestFixtures.laterDate)
        ])
        let records = try store.fetchAll()
        #expect(records.reduce(0) { $0 + $1.progress } / 4 == 0.25)
    }
}

@MainActor
struct ExamCompletionRegressionTests {
    @Test("Completing the same exam twice persists one attempt")
    func duplicateCompletionPersistsOnce() {
        let store = RecordingAttemptStore()
        let clock = MutableQuizClock(now: TestFixtures.startDate)
        let scheduler = ManualQuizScheduler()
        let engine = QuizEngine(
            configuration: .custom(questionCount: 2, timeLimitSeconds: 90, passMarkCount: 1),
            questionRepository: InMemoryQuestionRepository(TestFixtures.questions(count: 2)),
            attemptStore: store,
            clock: clock,
            scheduler: scheduler
        )
        engine.startExam(testID: "test-1")
        clock.now = TestFixtures.laterDate

        engine.finishExam()
        engine.finishExam()

        #expect(store.saved.count == 1)
        #expect(store.saved.first?.attemptDate == TestFixtures.laterDate)
        #expect(store.saved.first?.elapsedSeconds == 300)
        #expect(store.saved.first?.testID == "test-1")
    }

    @Test("Timeout completes and persists exactly once")
    func timeoutPersistsOnce() {
        let store = RecordingAttemptStore()
        let clock = MutableQuizClock(now: TestFixtures.startDate)
        let scheduler = ManualQuizScheduler()
        let engine = QuizEngine(
            configuration: .custom(questionCount: 1, timeLimitSeconds: 1, passMarkCount: 1),
            questionRepository: InMemoryQuestionRepository(TestFixtures.questions(count: 1)),
            attemptStore: store,
            clock: clock,
            scheduler: scheduler
        )

        engine.startExam(testID: "timeout")
        clock.now = TestFixtures.laterDate
        scheduler.fireRepeating()
        engine.finishExam()

        #expect(engine.phase == .results)
        #expect(engine.didTimeOut)
        #expect(store.saved.count == 1)
        #expect(store.saved.first?.didTimeOut == true)
    }

    @Test("Delayed submission and advancement are controlled by the scheduler")
    func delayedTransitionsAreControllable() {
        let store = RecordingAttemptStore()
        let scheduler = ManualQuizScheduler()
        let engine = QuizEngine(
            configuration: .custom(questionCount: 1, timeLimitSeconds: 90, passMarkCount: 1),
            questionRepository: InMemoryQuestionRepository(TestFixtures.questions(count: 1)),
            attemptStore: store,
            clock: MutableQuizClock(now: TestFixtures.startDate),
            scheduler: scheduler
        )

        engine.startExam()
        engine.toggleChoice(0, isMultiSelect: false)
        #expect(!engine.hasSubmittedAnswer)

        scheduler.runNextDelayed()
        #expect(engine.hasSubmittedAnswer)
        #expect(engine.phase == .question(index: 0))

        scheduler.runNextDelayed()
        #expect(engine.phase == .results)
        #expect(store.saved.count == 1)
    }
}

@MainActor
struct QuizStateMachineTests {
    @Test("State transitions do not require UI, timers, or persistence")
    func pureTransitions() {
        var state = QuizState(configuration: .custom(questionCount: 2, timeLimitSeconds: 2, passMarkCount: 1))
        let questions = TestFixtures.questions(count: 2)

        state.start(questions: questions, testID: "pure", at: TestFixtures.startDate)
        #expect(state.phase == .question(index: 0))
        #expect(state.toggleChoice(0) == .submitAfter(0.3))
        #expect(state.submitCurrentAnswer() == .advanceAfter(2))
        #expect(state.advance(at: TestFixtures.startDate) == .none)
        #expect(state.phase == .question(index: 1))

        #expect(state.tick(at: TestFixtures.laterDate) == .none)
        let completion = state.tick(at: TestFixtures.laterDate)
        guard case .completed(let exam) = completion else {
            Issue.record("Expected timeout completion")
            return
        }
        #expect(exam.didTimeOut)
        #expect(state.phase == .results)
        #expect(state.finish(at: TestFixtures.laterDate, timedOut: true) == .none)
    }
}

@MainActor
struct ContentRepositoryTests {
    @Test("In-memory repositories replace production content without feature changes")
    func inMemoryRepositoriesSupplyContent() throws {
        let questions = TestFixtures.questions(count: 3)
        let chapter = TestFixtures.searchChapter

        let selected = try InMemoryQuestionRepository(questions)
            .questions(count: 2, seed: "fixture")
        let chapters = try InMemoryHandbookRepository([chapter]).document().chapters

        #expect(selected.count == 2)
        #expect(Set(selected.map(\.id)).isSubset(of: Set(questions.map(\.id))))
        #expect(chapters.map(\.id) == [chapter.id])
    }

    @Test("Missing bundle resources produce explicit typed errors")
    func missingBundleResourcesThrow() {
        let questions = BundleQuestionRepository(resourceName: "missing-questions-fixture")
        let handbook = BundleHandbookRepository(resourceName: "missing-handbook-fixture")

        #expect(throws: ContentRepositoryError.resourceNotFound("missing-questions-fixture.json")) {
            try questions.questions(count: 1, seed: nil)
        }
        #expect(throws: ContentRepositoryError.resourceNotFound("missing-handbook-fixture.json")) {
            try handbook.document()
        }
    }

    @Test("Question loading failures are surfaced by the quiz engine")
    func quizEngineSurfacesRepositoryFailure() {
        let engine = QuizEngine(
            questionRepository: InMemoryQuestionRepository([]),
            clock: MutableQuizClock(now: TestFixtures.startDate),
            scheduler: ManualQuizScheduler()
        )

        engine.startExam()

        #expect(engine.phase == .lobby)
        #expect(engine.contentError == .emptyContent("in-memory questions"))
    }

    @Test("Handbook loading failures are retained for retryable UI state")
    func handbookCatalogSurfacesRepositoryFailure() {
        let catalog = HandbookCatalog(repository: InMemoryHandbookRepository([]))

        #expect(catalog.chapters.isEmpty)
        #expect(catalog.error == .emptyContent("in-memory handbook"))
        catalog.reload()
        #expect(catalog.error == .emptyContent("in-memory handbook"))
    }

    @Test("Production bundle repositories decode packaged content")
    func bundleRepositoriesLoadPackagedContent() throws {
        let questions = try BundleQuestionRepository().questions(count: 3, seed: "bundle-test")
        let document = try BundleHandbookRepository().document()
        let chapters = document.chapters

        #expect(questions.count == 3)
        #expect(!chapters.isEmpty)
        #expect(!chapters[0].sections.isEmpty)
        #expect(document.contentVersion > 0)
        #expect(document.validBlockIDs.count == Set(document.validBlockIDs).count)
    }

    @Test("Stable block IDs keep highlights attached after reordering")
    func blockReorderingPreservesHighlightIdentity() throws {
        let highlight = HighlightSnapshot(chapterID: "chapter_01", sectionID: "section_01", blockID: "block_a", textPreview: "A")
        let store = InMemoryHighlightStore(records: [highlight])
        let issues = PersistenceIssueCenter()
        let library = HighlightLibrary(store: store, issues: issues)
        let reordered = [ContentBlock(id: "block_b", content: .paragraph("B")), ContentBlock(id: "block_a", content: .paragraph("A"))]

        #expect(library.highlights.first?.blockID == reordered[1].id)
        #expect(library.highlights.first?.blockID != reordered[0].id)
    }

    @Test("Content migration rewrites renamed IDs and removes orphaned highlights")
    func contentIdentityMigrationPolicy() throws {
        let renamed = HighlightSnapshot(chapterID: "chapter_42", sectionID: "origins", blockID: "legacy_block", textPreview: "Magna", contentVersion: 1)
        let removed = HighlightSnapshot(chapterID: "chapter_42", sectionID: "origins", blockID: "removed_block", textPreview: "Removed", contentVersion: 1)
        let store = InMemoryHighlightStore(records: [renamed, removed])
        let library = HighlightLibrary(store: store, issues: PersistenceIssueCenter())
        let document = HandbookDocument(
            contentVersion: 2,
            identityMigrations: ContentIdentityMigrations(
                renamedChapterIDs: [:],
                renamedSectionIDs: [:],
                renamedBlockIDs: ["legacy_block": "origins_block_001"],
                removedBlockIDs: ["removed_block"]
            ),
            chapters: [TestFixtures.searchChapter]
        )

        library.reconcile(document: document)

        #expect(library.highlights.count == 1)
        #expect(library.highlights.first?.blockID == "origins_block_001")
        #expect(library.highlights.first?.contentVersion == 2)
    }
}

@MainActor
struct QuestionJSONDecodingTests {
    @Test("Valid question JSON decodes and maps multi-select answers")
    func validJSON() throws {
        let data = Data(TestFixtures.validQuestionJSON.utf8)
        let decoded = try JSONDecoder().decode(RawQuestionsFile.self, from: data)
        let question = try #require(decoded.data.first.map(QuizQuestion.init(from:)))

        #expect(question.id == "json-1")
        #expect(question.correctIndices == [0, 2])
        #expect(question.isMultiSelect)
        #expect(question.category == 3)
    }

    @Test("Malformed JSON throws")
    func invalidJSON() {
        let data = Data(#"{"data":[}"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RawQuestionsFile.self, from: data)
        }
    }

    @Test("Missing required question data throws")
    func missingData() {
        let data = Data(#"{"data":[{"question_id":"missing-fields"}]}"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RawQuestionsFile.self, from: data)
        }
    }
}

@MainActor
struct SearchTests {
    @Test("Search is case-insensitive and returns one result per section")
    func caseInsensitiveSectionSearch() throws {
        let chapter = TestFixtures.searchChapter
        let results = HandbookSearchEngine.performSearch(query: "mAgNa CaRtA", chapters: [chapter])

        #expect(results.count == 1)
        let result = try #require(results.first)
        #expect(result.chapter.id == chapter.id)
        #expect(result.sectionIndex == 0)
        #expect(result.snippet.lowercased().contains("magna carta"))
        #expect(result.matchRange.map { String(result.snippet[$0]).lowercased() } == "magna carta")
    }

    @Test("Search returns no result for an absent term")
    func absentSearchTerm() {
        let results = HandbookSearchEngine.performSearch(
            query: "parliament",
            chapters: [TestFixtures.searchChapter]
        )
        #expect(results.isEmpty)
    }
}

@MainActor
private enum TestFixtures {
    static let startDate = Date(timeIntervalSince1970: 1_700_000_000)
    static let laterDate = Date(timeIntervalSince1970: 1_700_000_300)

    static func question(id: String, correctIndices: Set<Int> = [0]) -> QuizQuestion {
        QuizQuestion(
            id: id,
            question: "Question \(id)",
            choices: ["A", "B", "C"],
            correctIndices: correctIndices,
            isMultiSelect: correctIndices.count > 1,
            year: "2026",
            category: 1,
            explanationLink: "section-1"
        )
    }

    static func questions(count: Int) -> [QuizQuestion] {
        (0..<count).map { question(id: "q-\($0)") }
    }

    static func modelContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ExamAttempt.self,
            ReadingProgress.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    static let searchChapter = HandbookChapter(
        id: 42,
        contentID: "chapter_42",
        number: "Chapter 42",
        title: "Test History",
        pillLabels: ["Origins"],
        sections: [
            HandbookSection(
                id: "origins",
                title: "Origins",
                blocks: [
                    ContentBlock(id: "origins_block_001", content: .paragraph("The **Magna Carta** was agreed in 1215.")),
                    ContentBlock(id: "origins_block_002", content: .paragraph("A second Magna Carta mention stays within the same section."))
                ]
            )
        ]
    )

    static let validQuestionJSON = #"""
    {
      "data": [{
        "question_id": "json-1",
        "book_section_id": "section-1",
        "category": "3",
        "question": "Choose two",
        "year": "2026",
        "choices": ["A", "B", "C"],
        "correct": ["0", "2"],
        "explanation": { "link": "section-1" }
      }]
    }
    """#
}

@MainActor
private final class RecordingAttemptStore: ExamAttemptStore {
    private(set) var saved: [CompletedExam] = []

    func fetchAll() throws -> [ExamAttemptSnapshot] { [] }

    func save(_ exam: CompletedExam) throws {
        saved.append(exam)
    }
}

private final class MutableQuizClock: QuizClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

@MainActor
private final class ManualQuizScheduler: QuizScheduler {
    private final class ScheduledAction {
        var isCancelled = false
        let action: @MainActor () -> Void

        init(action: @escaping @MainActor () -> Void) {
            self.action = action
        }
    }

    private var delayed: [ScheduledAction] = []
    private var repeating: [ScheduledAction] = []

    func schedule(after delay: TimeInterval, action: @escaping @MainActor () -> Void) -> QuizCancellation {
        let scheduled = ScheduledAction(action: action)
        delayed.append(scheduled)
        return QuizCancellation { scheduled.isCancelled = true }
    }

    func scheduleRepeating(every interval: TimeInterval, action: @escaping @MainActor () -> Void) -> QuizCancellation {
        let scheduled = ScheduledAction(action: action)
        repeating.append(scheduled)
        return QuizCancellation { scheduled.isCancelled = true }
    }

    func runNextDelayed() {
        while !delayed.isEmpty {
            let scheduled = delayed.removeFirst()
            if !scheduled.isCancelled {
                scheduled.action()
                return
            }
        }
    }

    func fireRepeating() {
        repeating.filter { !$0.isCancelled }.forEach { $0.action() }
    }
}
