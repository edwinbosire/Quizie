//
//  SearchView.swift
//  HandbookReaderQuiz
//
//  Created by Edwin Bosire on 01/04/2026.
//

import SwiftUI

// MARK: - Search View

struct SearchView: View {
    private let dependencies: SearchFeatureDependencies
    private var catalog: HandbookCatalog { dependencies.catalog }
    @State private var searchModel: HandbookSearchModel
    @State private var searchText = ""

    init(dependencies: SearchFeatureDependencies) {
        self.dependencies = dependencies
        _searchModel = State(initialValue: HandbookSearchModel(service: dependencies.service))
    }

    var body: some View {
        Group {
            if let error = searchModel.error ?? catalog.error {
                RepositoryErrorView(title: "Search Unavailable", error: error) {
                    catalog.reload()
                    searchModel.search(query: searchText)
                }
            } else if searchText.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                emptyState
            } else if searchModel.isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchModel.results.isEmpty {
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
            searchModel.search(query: newValue)
        }
        .navigationDestination(for: SearchNavDestination.self) { destination in
            ChapterView(
                chapter: destination.chapter,
                dependencies: dependencies.reader,
                initialSectionIndex: destination.sectionIndex,
                searchHighlight: destination.searchTerm
            )
        }
        .onDisappear { searchModel.cancel() }
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
                        ForEach(catalog.chapters) { chapter in
                            Button {
                                searchText = chapter.title
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
                    Text("\(searchModel.results.count) result\(searchModel.results.count == 1 ? "" : "s")")
                        .font(HBFont.sans(13, weight: .medium))
                        .foregroundColor(.hbTextMuted)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)

                ForEach(searchModel.results) { result in
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

// MARK: - Preview

#Preview("Search") {
    let dependencies = try! AppDependencies.preview()

    NavigationStack {
        SearchView(dependencies: dependencies.search)
    }
}

// MARK: - Navigation Destination
