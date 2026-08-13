import Foundation

/// An OpenAI-backed provider adapter. It talks only to Quizie's secure backend;
/// OpenAI credentials and API calls never live in the app process.
nonisolated struct OpenAIInferenceService: AIInferenceService {
    let baseURL: URL?
    private let session: URLSession

    init(baseURL: URL?, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    init(bundle: Bundle = .main, session: URLSession = .shared) {
        let environmentValue = ProcessInfo.processInfo.environment["FLASHCARD_API_BASE_URL"]
        let bundleValue = bundle.object(forInfoDictionaryKey: "FlashcardAPIBaseURL") as? String
        let configuredValue = environmentValue?.nilIfPlaceholder ?? bundleValue?.nilIfPlaceholder
        self.init(baseURL: configuredValue.flatMap(URL.init(string:)), session: session)
    }

    func generateFlashcards(from context: FlashcardGenerationContext) async throws -> [GeneratedFlashcard] {
        guard let baseURL else { throw AIInferenceError.notConfigured }
        let endpoint = baseURL.appending(path: "flashcards/generate")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        request.httpBody = try JSONEncoder().encode(context)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw AIInferenceError.invalidResponse }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let payload = try? JSONDecoder().decode(ServerErrorResponse.self, from: data)
            throw AIInferenceError.provider(statusCode: httpResponse.statusCode, message: payload?.error ?? "Flashcard generation failed. Please try again.")
        }

        let result = try JSONDecoder().decode(FlashcardGenerationResponse.self, from: data)
        let allowedBlockIDs = Set(context.blocks.map(\.id))
        let cards = result.cards.prefix(context.maxCards).filter { card in
            !card.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !card.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !card.sourceBlockIds.isEmpty &&
            card.sourceBlockIds.allSatisfy(allowedBlockIDs.contains)
        }
        guard !cards.isEmpty else { throw AIInferenceError.noCards }
        return cards.map { card in
            GeneratedFlashcard(question: card.question, answer: card.answer, sourceBlockIds: card.sourceBlockIds, taxonomy: context.taxonomy(for: card.sourceBlockIds))
        }
    }
}

private nonisolated struct ServerErrorResponse: Decodable {
    let error: String
}

private nonisolated extension String {
    var nilIfPlaceholder: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed.hasPrefix("$(") ? nil : trimmed
    }
}
