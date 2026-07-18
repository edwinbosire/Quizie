import SwiftUI

@MainActor
class PreviewQuizEngine {
    static var sampleEngine: QuizEngine {
        let engine = QuizEngine(questionRepository: InMemoryQuestionRepository([]))
        let mockQuestions = [
            QuizQuestion(
                id: "q1",
                question: "What year was the Declaration of Independence signed?",
                choices: [
                    "1774",
                    "1775",
                    "1776",
                    "1777"
                ],
                correctIndices: [2],
                isMultiSelect: false,
                year: "1776",
                category: 1,
                explanationLink: "https://example.com"
            ),
            QuizQuestion(
                id: "q2",
                question: "Which of the following are branches of the U.S. government?",
                choices: [
                    "Legislative",
                    "Executive",
                    "Judicial",
                    "Administrative"
                ],
                correctIndices: [0, 1, 2],
                isMultiSelect: true,
                year: "1787",
                category: 2,
                explanationLink: "https://example.com"
            ),
            QuizQuestion(
                id: "q3",
                question: "Who was the first President of the United States?",
                choices: [
                    "John Adams",
                    "Thomas Jefferson",
                    "George Washington",
                    "Benjamin Franklin"
                ],
                correctIndices: [2],
                isMultiSelect: false,
                year: "1789",
                category: 1,
                explanationLink: "https://example.com"
            )
        ]
        
        engine.setPreviewState(
            session: ExamSession(questions: mockQuestions),
            phase: .question(index: 0)
        )
        return engine
    }
    
    static var multiSelectEngine: QuizEngine {
        let engine = QuizEngine(questionRepository: InMemoryQuestionRepository([]))
        let mockQuestions = [
            QuizQuestion(
                id: "q1",
                question: "What year was the Declaration of Independence signed?",
                choices: [
                    "1774",
                    "1775",
                    "1776",
                    "1777"
                ],
                correctIndices: [2],
                isMultiSelect: false,
                year: "1776",
                category: 1,
                explanationLink: "https://example.com"
            ),
            QuizQuestion(
                id: "q2",
                question: "Which of the following are branches of the U.S. government? Select all that apply.",
                choices: [
                    "Legislative",
                    "Executive",
                    "Judicial",
                    "Administrative",
                    "Monetary"
                ],
                correctIndices: [0, 1, 2],
                isMultiSelect: true,
                year: "1787",
                category: 2,
                explanationLink: "https://example.com"
            )
        ]
        
        engine.setPreviewState(
            session: ExamSession(questions: mockQuestions),
            phase: .question(index: 1),
            selectedIndices: [0, 1],
            timeRemaining: 2400
        )
        return engine
    }
    
    static var timeWarningEngine: QuizEngine {
        let engine = QuizEngine(questionRepository: InMemoryQuestionRepository([]))
        let mockQuestions = [
            QuizQuestion(
                id: "q1",
                question: "What is the supreme law of the land?",
                choices: [
                    "The Declaration of Independence",
                    "The Constitution",
                    "The Bill of Rights",
                    "The Articles of Confederation"
                ],
                correctIndices: [1],
                isMultiSelect: false,
                year: "1787",
                category: 1,
                explanationLink: "https://example.com"
            )
        ]
        
        engine.setPreviewState(
            session: ExamSession(questions: mockQuestions),
            phase: .question(index: 0),
            timeRemaining: 240
        )
        return engine
    }
}
