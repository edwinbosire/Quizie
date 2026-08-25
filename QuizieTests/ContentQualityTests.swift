import Foundation
import Testing
@testable import BritReady__Life_in_UK_Test

struct ContentQualityAnalyzerTests {
    @Test("Analysis checks every content type and reports structural problems")
    func analyzesAllContentTypes() {
        let questions = [
            QuizQuestion(id: "duplicate", question: "Repeated prompt?", choices: ["Same", "same"], correctIndices: [], isMultiSelect: false, year: "", category: 1, explanationLink: ""),
            QuizQuestion(id: "duplicate", question: "Repeated prompt?", choices: ["Yes", "No"], correctIndices: [4], isMultiSelect: false, year: "", category: 1, explanationLink: "")
        ]
        let card = Flashcard(id: "card", prompt: "Which TWO answers are right?", answer: "Both", topic: "Test")
        let chapter = HandbookChapter(
            id: 0,
            contentID: "chapter",
            number: "Chapter 1",
            title: "",
            pillLabels: [],
            sections: [HandbookSection(id: "section", title: "Section", blocks: [])]
        )

        let analysis = ContentQualityAnalyzer.analyze(questions: questions, guideCards: [card], flashcardAudit: [], chapters: [chapter])

        #expect(analysis.questionCount == 2)
        #expect(analysis.flashcardCount == 1)
        #expect(analysis.handbookBlockCount == 0)
        #expect(analysis.findings.contains { $0.area == .questions && $0.message == "Duplicate question ID" })
        #expect(analysis.findings.contains { $0.area == .questions && $0.message == "Question contains duplicate choices" })
        #expect(analysis.findings.contains { $0.area == .questions && $0.message == "Correct answer points outside the choices" })
        #expect(analysis.findings.contains { $0.area == .flashcards && $0.message.contains("concise recall") })
        #expect(analysis.findings.contains { $0.area == .handbook && $0.message == "Chapter title is empty" })
        #expect(analysis.findings.contains { $0.area == .handbook && $0.message == "Section has no content blocks" })
    }

    @Test("Feedback email is addressed and contains stable content context")
    func reportEmailContainsContext() throws {
        let content = ContentReportContent(kind: .question, contentID: "q-42", prompt: "When?", answerContext: "✓ 1. 1215")
        let url = try #require(ContentFeedbackEmail.reportURL(content: content, category: .factualError, details: "This date looks wrong."))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in item.value.map { (item.name, $0) } })

        #expect(components.scheme == "mailto")
        #expect(components.path == ContentReviewSettings.feedbackAddress)
        #expect(query["subject"]?.contains("q-42") == true)
        #expect(query["body"]?.contains("This date looks wrong.") == true)
        #expect(query["body"]?.contains("✓ 1. 1215") == true)
    }
}
