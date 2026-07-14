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
        let questions = TestFixtures.questions(count: ExamSession.questionCount)
        var session = ExamSession(questions: questions, startedAt: TestFixtures.startDate)

        for question in questions.prefix(score) {
            session.submit(answer: question.correctIndices, for: question)
        }

        #expect(session.score == score)
        #expect(session.passed == (score >= ExamSession.passMarkCount))
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
    func seededQuestionSetIsDeterministic() {
        let bank = QuestionBank(questions: TestFixtures.questions(count: 10))

        let first = bank.generateExam(count: 5, seed: "practice-test-4").map(\.id)
        let second = bank.generateExam(count: 5, seed: "practice-test-4").map(\.id)

        #expect(first == ["q-2", "q-7", "q-0", "q-3", "q-4"])
        #expect(second == first)
    }
}

@MainActor
struct ProgressTests {
    @Test("Quiz progress is based on the current zero-based index")
    func quizProgressFraction() {
        let engine = QuizEngine(bank: QuestionBank(questions: []), now: { TestFixtures.startDate })
        engine.session = ExamSession(
            questions: TestFixtures.questions(count: 4),
            startedAt: TestFixtures.startDate
        )

        engine.phase = .question(index: 0)
        #expect(engine.progressFraction == 0)

        engine.phase = .question(index: 2)
        #expect(engine.progressFraction == 0.5)
    }

    @Test("Reading progress clamps scroll calculations")
    func readingProgressCalculation() {
        let progress = ReadingProgress(chapterId: 1, lastReadDate: TestFixtures.startDate)

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
        let container = try TestFixtures.modelContainer()
        let context = container.mainContext
        context.insert(ReadingProgress(chapterId: 1, progress: 0.25, lastReadDate: TestFixtures.startDate))
        context.insert(ReadingProgress(chapterId: 2, progress: 0.75, lastReadDate: TestFixtures.laterDate))
        try context.save()

        #expect(ReadingProgress.overallCompletionPercentage(totalChapters: 4, in: context) == 0.25)
    }
}

@MainActor
struct ExamCompletionRegressionTests {
    @Test("Completing the same exam twice persists one attempt")
    func duplicateCompletionPersistsOnce() throws {
        let container = try TestFixtures.modelContainer()
        let engine = QuizEngine(
            bank: QuestionBank(questions: []),
            now: { TestFixtures.laterDate }
        )
        engine.modelContext = container.mainContext
        engine.session = ExamSession(
            testID: "test-1",
            questions: TestFixtures.questions(count: 2),
            startedAt: TestFixtures.startDate
        )
        engine.phase = .question(index: 1)

        engine.finishExam()
        engine.finishExam()

        let attempts = try container.mainContext.fetch(FetchDescriptor<ExamAttempt>())
        #expect(attempts.count == 1)
        #expect(attempts.first?.attemptDate == TestFixtures.laterDate)
        #expect(attempts.first?.elapsedSeconds == 300)
        #expect(attempts.first?.testID == "test-1")
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
        number: "Chapter 42",
        title: "Test History",
        pillLabels: ["Origins"],
        sections: [
            HandbookSection(
                id: "origins",
                title: "Origins",
                blocks: [
                    .paragraph("The **Magna Carta** was agreed in 1215."),
                    .paragraph("A second Magna Carta mention stays within the same section.")
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
