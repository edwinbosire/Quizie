import Foundation

struct Flashcard: Identifiable, Equatable {
    let id: String
    let prompt: String
    let answer: String
    let topic: String
}

enum FlashcardRating: Equatable {
    case learning
    case known
}

extension Flashcard {
    init(question: QuizQuestion) {
        id = question.id
        prompt = question.question
        answer = question.correctChoices.joined(separator: "\n")
        topic = "Chapter \(question.category)"
    }
}
