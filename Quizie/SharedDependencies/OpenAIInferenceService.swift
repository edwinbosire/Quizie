import Foundation

/// An OpenAI-backed provider adapter. It talks only to Quizie's secure backend;
/// OpenAI credentials and API calls never live in the app process.
nonisolated struct OpenAIInferenceService: AIInferenceService {
    let baseURL: URL?
    private let appToken: String?
    private let session: URLSession

    init(baseURL: URL?, appToken: String? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.appToken = appToken
        self.session = session
    }

    init(bundle: Bundle = .main, session: URLSession = .shared) {
        self.init(
            baseURL: Self.configuredValue(key: "FLASHCARD_API_BASE_URL", infoKey: "FlashcardAPIBaseURL", bundle: bundle).flatMap(URL.init(string:)),
            appToken: Self.configuredValue(key: "FLASHCARD_APP_TOKEN", infoKey: "FlashcardAPIToken", bundle: bundle),
            session: session
        )
    }

    private static func configuredValue(key: String, infoKey: String, bundle: Bundle) -> String? {
        let environmentValue = ProcessInfo.processInfo.environment[key]
        let bundleValue = bundle.object(forInfoDictionaryKey: infoKey) as? String
        return environmentValue?.nilIfPlaceholder ?? bundleValue?.nilIfPlaceholder
    }

    func generateFlashcards(from context: FlashcardGenerationContext) async throws -> [GeneratedFlashcard] {
        guard let baseURL, let appToken else { throw AIInferenceError.notConfigured }
        let endpoint = baseURL.appending(path: "flashcards/generate")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(appToken)", forHTTPHeaderField: "Authorization")
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
            FlashcardRecallStyle.isValid(question: card.question, answer: card.answer) &&
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
