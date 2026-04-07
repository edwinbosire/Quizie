//
//  SearchView.swift
//  HandbookReaderQuiz
//
//  Created by Edwin Bosire on 01/04/2026.
//

import SwiftUI

// MARK: - Search Result Model

struct SearchResult: Identifiable {
    let id = UUID()
    let chapter: HandbookChapter
    let section: HandbookSection
    let sectionIndex: Int
    let matchedText: String      // The full text of the block that matched
    let snippet: String           // A trimmed snippet around the match
    let matchRange: Range<String.Index>? // Range of the query within the snippet
}

// MARK: - Search Engine

@Observable
final class HandbookSearchEngine {
    var results: [SearchResult] = []
    var isSearching = false

    private var searchTask: Task<Void, Never>?

    func search(query: String) {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            isSearching = false
            return
        }

        isSearching = true

        searchTask = Task { @MainActor in
            // Small delay to debounce rapid typing
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }

            let found = Self.performSearch(query: trimmed)
            guard !Task.isCancelled else { return }

            results = found
            isSearching = false
        }
    }

    private static func performSearch(query: String) -> [SearchResult] {
        let lowercasedQuery = query.lowercased()
        var results: [SearchResult] = []

        for chapter in HandbookData.chapters {
            for (sectionIndex, section) in chapter.sections.enumerated() {
                for block in section.blocks {
                    let plainText = block.plainText
                    guard !plainText.isEmpty else { continue }

                    let lowercasedText = plainText.lowercased()
                    guard let matchRange = lowercasedText.range(of: lowercasedQuery) else { continue }

                    // Build a snippet around the match
                    let snippet = Self.buildSnippet(
                        from: plainText,
                        matchRange: matchRange,
                        maxLength: 160
                    )

                    results.append(SearchResult(
                        chapter: chapter,
                        section: section,
                        sectionIndex: sectionIndex,
                        matchedText: plainText,
                        snippet: snippet.text,
                        matchRange: snippet.highlightRange
                    ))

                    // Limit to one result per section to avoid flooding
                    break
                }
            }
        }
        return results
    }

    private static func buildSnippet(
        from text: String,
        matchRange: Range<String.Index>,
        maxLength: Int
    ) -> (text: String, highlightRange: Range<String.Index>?) {
        let matchStart = text.distance(from: text.startIndex, to: matchRange.lowerBound)
        let matchEnd = text.distance(from: text.startIndex, to: matchRange.upperBound)

        // Center the snippet around the match
        let contextBefore = 40
        let snippetStart = max(0, matchStart - contextBefore)
        let snippetEnd = min(text.count, snippetStart + maxLength)

        let startIdx = text.index(text.startIndex, offsetBy: snippetStart)
        let endIdx = text.index(text.startIndex, offsetBy: min(snippetEnd, text.count))

        var snippet = String(text[startIdx..<endIdx])

        // Add ellipsis if trimmed
        let prefix = snippetStart > 0 ? "..." : ""
        let suffix = snippetEnd < text.count ? "..." : ""
        snippet = prefix + snippet.trimmingCharacters(in: .whitespacesAndNewlines) + suffix

        // Calculate highlight range within the snippet
        let offsetInSnippet = matchStart - snippetStart + prefix.count
        let queryLength = matchEnd - matchStart

        let highlightStart = snippet.index(snippet.startIndex, offsetBy: max(0, min(offsetInSnippet, snippet.count)))
        let highlightEnd = snippet.index(highlightStart, offsetBy: min(queryLength, snippet.distance(from: highlightStart, to: snippet.endIndex)))

        return (snippet, highlightStart..<highlightEnd)
    }
}

// MARK: - ContentBlock Plain Text Extraction

extension ContentBlock {
    var plainText: String {
        switch self {
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
    /// Strip **bold** markers for plain text search
    var strippingMarkdownBold: String {
        replacingOccurrences(of: "**", with: "")
    }
}

// MARK: - Search Suggestions

struct SearchSuggestion: Identifiable {
    let id = UUID()
    let text: String
    let icon: String
    let category: String
}

private let curatedSuggestions: [SearchSuggestion] = [
    SearchSuggestion(text: "Democracy", icon: "building.columns", category: "Values"),
    SearchSuggestion(text: "Magna Carta", icon: "scroll", category: "History"),
    SearchSuggestion(text: "Henry VIII", icon: "crown", category: "History"),
    SearchSuggestion(text: "Parliament", icon: "building.columns", category: "Government"),
    SearchSuggestion(text: "Shakespeare", icon: "theatermasks", category: "Culture"),
    SearchSuggestion(text: "World War", icon: "globe.europe.africa", category: "History"),
    SearchSuggestion(text: "Scotland", icon: "map", category: "Geography"),
    SearchSuggestion(text: "Citizenship", icon: "person.text.rectangle", category: "Rights"),
    SearchSuggestion(text: "Queen Elizabeth", icon: "crown", category: "History"),
    SearchSuggestion(text: "Bronze Age", icon: "clock.arrow.circlepath", category: "History"),
    SearchSuggestion(text: "Northern Ireland", icon: "map", category: "Geography"),
    SearchSuggestion(text: "Bill of Rights", icon: "doc.text", category: "Government"),
]

// MARK: - Search View

struct SearchView: View {
    @State private var searchEngine = HandbookSearchEngine()
    @State private var searchText = ""
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                    emptyState
                } else if searchEngine.isSearching {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchEngine.results.isEmpty {
                    noResults
                } else {
                    resultsList
                }
            }
            .background(Color.hbBackground)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search the handbook...")
            .onChange(of: searchText) { _, newValue in
                searchEngine.search(query: newValue)
            }
            .navigationDestination(for: SearchNavDestination.self) { destination in
                ChapterView(chapter: destination.chapter, initialSectionIndex: destination.sectionIndex)
                    .environment(\.searchHighlight, destination.searchTerm)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 44, weight: .light))
                        .foregroundColor(.hbTextMuted.opacity(0.5))

                    Text("Search the Handbook")
                        .font(HBFont.lora(20))
                        .foregroundColor(.hbTextPrimary)

                    Text("Find topics, facts, and key information\nacross all chapters.")
                        .font(HBFont.sans(15))
                        .foregroundColor(.hbTextMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.top, 16)

                // Suggestions
                VStack(alignment: .leading, spacing: 12) {
                    Text("SUGGESTED SEARCHES")
                        .font(HBFont.sans(11, weight: .semibold))
                        .kerning(1.5)
                        .foregroundColor(.hbTextMuted)
                        .padding(.horizontal, 4)

                    FlowLayout(spacing: 8) {
                        ForEach(curatedSuggestions) { suggestion in
                            Button {
                                searchText = suggestion.text
                                searchEngine.search(query: suggestion.text)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: suggestion.icon)
                                        .font(.system(size: 12))
                                        .foregroundColor(.hbAccent)

                                    Text(suggestion.text)
                                        .font(HBFont.sans(14, weight: .medium))
                                        .foregroundColor(.hbTextSecondary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.hbSurface)
                                .overlay(
                                    Capsule()
                                        .stroke(Color.hbBorder, lineWidth: 1)
                                )
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Browse by chapter
                VStack(alignment: .leading, spacing: 12) {
                    Text("BROWSE BY CHAPTER")
                        .font(HBFont.sans(11, weight: .semibold))
                        .kerning(1.5)
                        .foregroundColor(.hbTextMuted)
                        .padding(.horizontal, 4)

                    VStack(spacing: 8) {
                        ForEach(HandbookData.chapters) { chapter in
                            Button {
                                searchText = chapter.title
                                searchEngine.search(query: chapter.title)
                            } label: {
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(ChapterTheme.forChapter(chapter.id).accent)
                                        .frame(width: 4, height: 32)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(chapter.number.uppercased())
                                            .font(HBFont.sans(10, weight: .semibold))
                                            .kerning(1)
                                            .foregroundColor(.hbTextMuted)

                                        Text(chapter.title)
                                            .font(HBFont.sans(14, weight: .medium))
                                            .foregroundColor(.hbTextPrimary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.hbTextMuted)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.hbSurface)
                                .clipShape(RoundedRectangle(cornerRadius: HBRadius.sm))
                                .overlay(
                                    RoundedRectangle(cornerRadius: HBRadius.sm)
                                        .stroke(Color.hbBorder, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - No Results

    private var noResults: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.hbTextMuted.opacity(0.4))

            Text("No results for \"\(searchText)\"")
                .font(HBFont.sans(16, weight: .semibold))
                .foregroundColor(.hbTextPrimary)

            Text("Try a different search term or check your spelling.")
                .font(HBFont.sans(14))
                .foregroundColor(.hbTextMuted)

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Results List

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Results count header
                HStack {
                    Text("\(searchEngine.results.count) result\(searchEngine.results.count == 1 ? "" : "s")")
                        .font(HBFont.sans(13, weight: .medium))
                        .foregroundColor(.hbTextMuted)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)

                ForEach(searchEngine.results) { result in
                    NavigationLink(value: SearchNavDestination(chapter: result.chapter, sectionIndex: result.sectionIndex, searchTerm: searchText)) {
                        SearchResultRow(result: result, query: searchText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Navigation Destination

struct SearchNavDestination: Hashable {
    let chapter: HandbookChapter
    let sectionIndex: Int
    let searchTerm: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(chapter.id)
        hasher.combine(sectionIndex)
        hasher.combine(searchTerm)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.chapter.id == rhs.chapter.id && lhs.sectionIndex == rhs.sectionIndex && lhs.searchTerm == rhs.searchTerm
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let result: SearchResult
    let query: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                // Chapter + section breadcrumb
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ChapterTheme.forChapter(result.chapter.id).accent)
                        .frame(width: 3, height: 14)

                    Text(result.chapter.number)
                        .font(HBFont.sans(12, weight: .semibold))
                        .foregroundColor(.hbTextMuted)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.hbTextMuted.opacity(0.5))

                    Text(result.section.title)
                        .font(HBFont.sans(12, weight: .medium))
                        .foregroundColor(ChapterTheme.forChapter(result.chapter.id).accent)
                        .lineLimit(1)
                }

                // Snippet with highlighted match
                highlightedSnippet
                    .font(HBFont.sans(14))
                    .foregroundColor(.hbTextSecondary)
                    .lineSpacing(4)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                // Chapter title
                Text(result.chapter.title)
                    .font(HBFont.sans(12))
                    .foregroundColor(.hbTextMuted)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()
                .padding(.leading, 20)
        }
    }

    private var highlightedSnippet: Text {
        guard let range = result.matchRange,
              range.lowerBound >= result.snippet.startIndex,
              range.upperBound <= result.snippet.endIndex else {
            return Text(result.snippet)
        }

        var attributed = AttributedString(result.snippet)
        if let attrRange = Range(range, in: attributed) {
            attributed[attrRange].font = HBFont.sans(14, weight: .semibold)
            attributed[attrRange].foregroundColor = .hbAccent
        }
        return Text(attributed)
    }
}

#Preview {
    SearchView()
}
