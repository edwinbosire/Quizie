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
                        .appFont(.largeTitle.weight(.light))
                        .foregroundColor(.hbTextMuted.opacity(0.5))

                    Text("Search the Handbook")
                        .appFont(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundColor(.hbTextPrimary)

                    Text("Find topics, facts, and key information\nacross all chapters.")
                        .appFont(.subheadline)
                        .foregroundColor(.hbTextMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 16)

                // Suggestions
                VStack(alignment: .leading, spacing: 12) {
                    Text("SUGGESTED SEARCHES")
                        .appFont(.caption2.weight(.semibold))
                        .foregroundColor(.hbTextMuted)
                        .padding(.horizontal, 4)

                    FlowLayout(spacing: 8) {
                        ForEach(curatedSuggestions) { suggestion in
                            Button {
                                searchText = suggestion.text
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: suggestion.icon)
                                        .appFont(.caption)
                                        .foregroundColor(.hbAccent)

                                    Text(suggestion.text)
                                        .appFont(.footnote.weight(.medium))
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
                        .appFont(.caption2.weight(.semibold))
                        .foregroundColor(.hbTextMuted)
                        .padding(.horizontal, 4)

                    VStack(spacing: 8) {
                        ForEach(catalog.chapters) { chapter in
                            Button {
                                searchText = chapter.title
                            } label: {
                                ChapterBrowseRow(
                                    chapterNumber: chapter.number,
                                    title: chapter.title,
                                    chapterIndex: chapter.id,
                                    trailingSystemImage: "magnifyingglass"
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
                .appFont(.largeTitle.weight(.light))
                .foregroundColor(.hbTextMuted.opacity(0.4))

            Text("No results for \"\(searchText)\"")
                .appFont(.callout.weight(.semibold))
                .foregroundColor(.hbTextPrimary)

            Text("Try a different search term or check your spelling.")
                .appFont(.footnote)
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
                        .appFont(.footnote.weight(.medium))
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
