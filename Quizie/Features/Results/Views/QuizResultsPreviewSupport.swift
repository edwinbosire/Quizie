import SwiftUI

@MainActor
class PreviewResultsEngine {
    static var passedEngine: QuizEngine {
        let engine = QuizEngine(questionRepository: InMemoryQuestionRepository([]))
        let mockQuestions = createMockQuestions()
        
        var session = ExamSession(questions: mockQuestions)
        session.startedAt = Date().addingTimeInterval(-2100) // 35 minutes ago
        session.finishedAt = Date()
        
        // Simulate 20 correct answers (passed)
        for question in mockQuestions.prefix(20) {
            session.submit(answer: question.correctIndices, for: question)
        }
        // 4 wrong answers
        for question in mockQuestions.suffix(4) {
            let wrongAnswer = Set([1]) // Wrong answer (correct is 0)
            session.submit(answer: wrongAnswer, for: question)
        }
        
        engine.setPreviewState(session: session, phase: .results)
        return engine
    }
    
    static var failedEngine: QuizEngine {
        let engine = QuizEngine(questionRepository: InMemoryQuestionRepository([]))
        let mockQuestions = createMockQuestions()
        
        var session = ExamSession(questions: mockQuestions)
        session.startedAt = Date().addingTimeInterval(-2400) // 40 minutes ago
        session.finishedAt = Date()
        
        // Simulate 15 correct answers (failed - need 18)
        for question in mockQuestions.prefix(15) {
            session.submit(answer: question.correctIndices, for: question)
        }
        // 9 wrong answers
        for question in mockQuestions.suffix(9) {
            let wrongAnswer = Set([1]) // Wrong answer (correct is 0)
            session.submit(answer: wrongAnswer, for: question)
        }
        
        engine.setPreviewState(session: session, phase: .results)
        return engine
    }
    
    private static func createMockQuestions() -> [QuizQuestion] {
        return (1...24).map { i in
            QuizQuestion(
                id: "q\(i)",
                question: "Question \(i): What is the capital of England?",
                choices: [
                    "London",
                    "Manchester",
                    "Birmingham",
                    "Liverpool"
                ],
                correctIndices: [0],
                isMultiSelect: false,
                year: "1066",
                category: 1,
                explanationLink: "https://example.com"
            )
        }
    }
}
