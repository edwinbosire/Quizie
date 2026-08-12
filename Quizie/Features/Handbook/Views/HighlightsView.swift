import SwiftUI

struct HighlightsView: View {
    let dependencies: HandbookReaderDependencies
    private var catalog: HandbookCatalog { dependencies.catalog }
    private var library: HighlightLibrary { dependencies.highlights }
    private var highlights: [HighlightSnapshot] { library.highlights }

    /// Highlights grouped by chapter ID, preserving chapter order
    private var groupedHighlights: [(chapter: HandbookChapter, highlights: [HighlightSnapshot])] {
        let grouped = Dictionary(grouping: highlights) { $0.chapterID }
        return catalog.chapters.compactMap { chapter in
            guard let items = grouped[chapter.contentID], !items.isEmpty else { return nil }
            return (chapter: chapter, highlights: items)
        }
    }

    var body: some View {
        Group {
            if highlights.isEmpty {
                emptyState
            } else {
                highlightsList
            }
        }
        .navigationTitle("My Highlights")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "highlighter")
                .appFont(.largeTitle)
                .foregroundColor(.hbTextMuted.opacity(0.4))

            Text("No Highlights Yet")
                .appFont(.headline.weight(.semibold))
                .foregroundColor(.hbTextPrimary)

            Text("Long-press any paragraph while reading\nto save a highlight.")
                .appFont(.footnote)
                .foregroundColor(.hbTextMuted)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - Highlights List

    private var highlightsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(groupedHighlights, id: \.chapter.id) { group in
                    chapterSection(chapter: group.chapter, highlights: group.highlights)
                }
            }
            .padding(.bottom, 32)
        }
        .background(Color.hbBackground)
    }

    @ViewBuilder
    private func chapterSection(chapter: HandbookChapter, highlights: [HighlightSnapshot]) -> some View {
        let theme = ChapterTheme.forChapter(chapter.id)

        // Chapter header
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(theme.accent)
                .frame(width: 4, height: 20)

            Text(chapter.number.uppercased())
                .appFont(.caption2.weight(.semibold))
                .foregroundColor(.hbTextMuted)

            Text(chapter.title)
                .appFont(.footnote.weight(.medium))
                .foregroundColor(.hbTextPrimary)

            Spacer()

            Text("\(highlights.count)")
                .appFont(.caption.weight(.semibold))
                .foregroundColor(.hbTextMuted)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)

        // Highlight rows
        ForEach(highlights) { highlight in
            NavigationLink {
                ChapterView(
                    chapter: chapter,
                    dependencies: dependencies,
                    initialSectionIndex: sectionIndex(for: highlight, in: chapter)
                )
            } label: {
                HighlightRow(highlight: highlight, chapter: chapter)
            }
            .buttonStyle(.plain)
        }
    }

    private func sectionIndex(
        for highlight: HighlightSnapshot,
        in chapter: HandbookChapter
    ) -> Int {
        chapter.sections.firstIndex { $0.id == highlight.sectionID } ?? 0
    }
}

// MARK: - Highlight Row

struct HighlightRow: View {
    let highlight: HighlightSnapshot
    let chapter: HandbookChapter

    private var sectionTitle: String {
        chapter.sections.first { $0.id == highlight.sectionID }?.title ?? ""
    }

    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: highlight.createdDate, relativeTo: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Color indicator bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(highlight.highlightColor.displayColor)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 6) {
                    // Section title
                    Text(sectionTitle)
                        .appFont(.footnote.weight(.semibold))
                        .foregroundColor(.hbTextPrimary)

                    // Text preview
                    Text(highlight.textPreview)
                        .appFont(.footnote)
                        .foregroundColor(.hbTextSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    // Date
                    Text(relativeDate)
                        .appFont(.caption2)
                        .foregroundColor(.hbTextMuted)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .appFont(.caption.weight(.medium))
                    .foregroundColor(.hbTextMuted.opacity(0.5))
                    .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()
                .padding(.leading, 36)
        }
    }
}

#Preview {
    let services = PersistenceServices(attemptStore: InMemoryExamAttemptStore(), progressStore: InMemoryReadingProgressStore(), highlightStore: InMemoryHighlightStore())
    let dependencies = HandbookReaderDependencies(
        catalog: HandbookCatalog(repository: BundleHandbookRepository()),
        progress: services.progress,
        highlights: services.highlights,
        aiInference: MockInferenceService(),
        flashcardMemory: services.flashcards
    )
    NavigationStack {
        HighlightsView(dependencies: dependencies)
    }
}
