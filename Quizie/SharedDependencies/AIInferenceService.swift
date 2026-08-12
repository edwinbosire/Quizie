import Foundation

nonisolated protocol AIInferenceService: Sendable {
    func generateFlashcards(from context: FlashcardGenerationContext) async throws -> [GeneratedFlashcard]
    func answer(_ question: String, context: TutorContext) async throws -> TutorResponse
}

nonisolated struct TutorContext: Codable, Equatable, Sendable {
    let chapter: String
    let section: String
    let context: String
    let sourceBlockIds: [String]
}

nonisolated struct TutorResponse: Codable, Equatable, Sendable {
    let answer: String
    let sourceBlockIds: [String]
}

nonisolated enum AIInferenceError: Error, Equatable, LocalizedError {
    case notConfigured
    case invalidResponse
    case provider(statusCode: Int, message: String)
    case noCards
    case unsupportedCapability(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AI inference is not configured. Set FLASHCARD_API_BASE_URL to your secure backend URL."
        case .invalidResponse:
            return "The AI inference service returned an invalid response."
        case .provider(_, let message):
            return message
        case .noCards:
            return "No testable facts were found in this selection. Try selecting a little more handbook text."
        case .unsupportedCapability(let capability):
            return "This AI provider does not support \(capability)."
        }
    }
}

nonisolated extension AIInferenceService {
    func answer(_ question: String, context: TutorContext) async throws -> TutorResponse {
        throw AIInferenceError.unsupportedCapability("tutor answers")
    }
}

nonisolated struct MockInferenceService: AIInferenceService {
    let flashcards: [GeneratedFlashcard]
    let tutorResponse: TutorResponse?

    init(flashcards: [GeneratedFlashcard] = [], tutorResponse: TutorResponse? = nil) {
        self.flashcards = flashcards
        self.tutorResponse = tutorResponse
    }

    func generateFlashcards(from context: FlashcardGenerationContext) async throws -> [GeneratedFlashcard] {
        flashcards
    }

    func answer(_ question: String, context: TutorContext) async throws -> TutorResponse {
        guard let tutorResponse else { throw AIInferenceError.unsupportedCapability("tutor answers") }
        return tutorResponse
    }
}
