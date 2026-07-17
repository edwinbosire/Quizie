import Foundation

nonisolated struct HandbookSearchResult: Identifiable, Sendable, Equatable {
    /// Stable across launches and query casing because it comes exclusively
    /// from authored content identity.
    let id: String
    let chapter: HandbookChapter
    let section: HandbookSection
    let sectionIndex: Int
    let blockID: String
    let matchedText: String
    let snippet: String
    let matchRange: Range<String.Index>?
}

nonisolated protocol HandbookSearchServing: Sendable {
    nonisolated func search(query: String) async throws -> [HandbookSearchResult]
}

/// Repository-backed search boundary. The UI depends on
/// `HandbookSearchServing`, so this implementation can later be replaced by a
/// prebuilt index without changing SearchView or its presentation model.
nonisolated struct HandbookSearchService: HandbookSearchServing, Sendable {
    private let repository: any HandbookRepository
    private let maximumSnippetLength: Int

    init(repository: any HandbookRepository, maximumSnippetLength: Int = 160) {
        self.repository = repository
        self.maximumSnippetLength = maximumSnippetLength
    }

    nonisolated func search(query: String) async throws -> [HandbookSearchResult] {
        let repository = self.repository
        let maximumSnippetLength = self.maximumSnippetLength
        let cancellation = SearchCancellationToken()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try cancellation.check()
                        let document = try repository.document()
                        let results = try Self.search(
                            query: query,
                            chapters: document.chapters,
                            maximumSnippetLength: maximumSnippetLength,
                            cancellationCheck: cancellation.check
                        )
                        continuation.resume(returning: results)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } onCancel: {
            cancellation.cancel()
        }
    }

    /// Pure search entry point used by tests and future index builders.
    nonisolated static func search(
        query: String,
        chapters: [HandbookChapter],
        maximumSnippetLength: Int = 160
    ) throws -> [HandbookSearchResult] {
        try search(
            query: query,
            chapters: chapters,
            maximumSnippetLength: maximumSnippetLength,
            cancellationCheck: Task.checkCancellation
        )
    }

    nonisolated private static func search(
        query: String,
        chapters: [HandbookChapter],
        maximumSnippetLength: Int,
        cancellationCheck: () throws -> Void
    ) throws -> [HandbookSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var results: [HandbookSearchResult] = []
        for chapter in chapters {
            try cancellationCheck()
            for (sectionIndex, section) in chapter.sections.enumerated() {
                try cancellationCheck()
                for block in section.blocks {
                    try cancellationCheck()
                    let text = block.plainText
                    guard let match = text.range(
                        of: trimmed,
                        options: [.caseInsensitive, .diacriticInsensitive],
                        locale: Locale(identifier: "en_GB")
                    ) else { continue }

                    let snippet = makeSnippet(from: text, matchRange: match, maximumLength: maximumSnippetLength)
                    results.append(HandbookSearchResult(
                        id: "\(chapter.contentID)/\(section.id)/\(block.id)",
                        chapter: chapter,
                        section: section,
                        sectionIndex: sectionIndex,
                        blockID: block.id,
                        matchedText: text,
                        snippet: snippet.text,
                        matchRange: snippet.highlightRange
                    ))
                    // Preserve the current one-result-per-section behavior.
                    break
                }
            }
        }
        return results
    }

    nonisolated private static func makeSnippet(
        from text: String,
        matchRange: Range<String.Index>,
        maximumLength: Int
    ) -> (text: String, highlightRange: Range<String.Index>?) {
        let matchStart = text.distance(from: text.startIndex, to: matchRange.lowerBound)
        let matchLength = text.distance(from: matchRange.lowerBound, to: matchRange.upperBound)
        let startOffset = max(0, matchStart - 40)
        let endOffset = min(text.count, startOffset + maximumLength)
        let start = text.index(text.startIndex, offsetBy: startOffset)
        let end = text.index(text.startIndex, offsetBy: endOffset)
        let prefix = startOffset > 0 ? "..." : ""
        let suffix = endOffset < text.count ? "..." : ""
        let body = String(text[start..<end])
        let snippet = prefix + body + suffix

        let highlightOffset = max(0, matchStart - startOffset + prefix.count)
        guard highlightOffset <= snippet.count else { return (snippet, nil) }
        let highlightStart = snippet.index(snippet.startIndex, offsetBy: highlightOffset)
        let availableLength = snippet.distance(from: highlightStart, to: snippet.endIndex)
        let highlightEnd = snippet.index(highlightStart, offsetBy: min(matchLength, availableLength))
        return (snippet, highlightStart..<highlightEnd)
    }
}

nonisolated private final class SearchCancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var isCancelled = false

    nonisolated func cancel() {
        lock.withLock { isCancelled = true }
    }

    nonisolated func check() throws {
        if lock.withLock({ isCancelled }) { throw CancellationError() }
    }
}

extension ContentBlock {
    nonisolated var plainText: String {
        switch content {
        case .paragraph(let text):
            return text.strippingMarkdownBold
        case .subheading(let text), .subheading2(let text), .blockquote(let text):
            return text
        case .bulletList(let items):
            return items.map { $0.text.raw.strippingMarkdownBold }.joined(separator: " ")
        case .checkUnderstand(let items):
            return items.joined(separator: " ")
        case .dataTable(let headers, let rows):
            return (headers + rows.flatMap { $0 }).joined(separator: " ")
        }
    }
}

private extension String {
    nonisolated var strippingMarkdownBold: String { replacingOccurrences(of: "**", with: "") }
}
