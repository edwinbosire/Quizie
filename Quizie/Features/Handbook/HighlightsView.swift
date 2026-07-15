import SwiftUI
import SwiftData

struct HighlightsView: View {
	@Environment(HandbookCatalog.self) private var catalog
    @Query(sort: [SortDescriptor(\Highlight.chapterId), SortDescriptor(\Highlight.createdDate, order: .reverse)])
    private var highlights: [Highlight]

    /// Highlights grouped by chapter ID, preserving chapter order
    private var groupedHighlights: [(chapter: HandbookChapter, highlights: [Highlight])] {
        let grouped = Dictionary(grouping: highlights) { $0.chapterId }
        return catalog.chapters.compactMap { chapter in
            guard let items = grouped[chapter.id], !items.isEmpty else { return nil }
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
        .navigationDestination(for: HighlightNavDestination.self) { destination in
            ChapterView(chapter: destination.chapter, initialSectionIndex: destination.sectionIndex)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "highlighter")
                .font(.system(size: 48))
                .foregroundColor(.hbTextMuted.opacity(0.4))

            Text("No Highlights Yet")
                .font(HBFont.sans(18, weight: .semibold))
                .foregroundColor(.hbTextPrimary)

            Text("Long-press any paragraph while reading\nto save a highlight.")
                .font(HBFont.sans(14))
                .foregroundColor(.hbTextMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

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
    private func chapterSection(chapter: HandbookChapter, highlights: [Highlight]) -> some View {
        let theme = ChapterTheme.forChapter(chapter.id)

        // Chapter header
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(theme.accent)
                .frame(width: 4, height: 20)

            Text(chapter.number.uppercased())
                .font(HBFont.sans(11, weight: .semibold))
                .kerning(1)
                .foregroundColor(.hbTextMuted)

            Text(chapter.title)
                .font(HBFont.sans(13, weight: .medium))
                .foregroundColor(.hbTextPrimary)
                .lineLimit(1)

            Spacer()

            Text("\(highlights.count)")
                .font(HBFont.sans(12, weight: .semibold))
                .foregroundColor(.hbTextMuted)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)

        // Highlight rows
        ForEach(highlights) { highlight in
            NavigationLink(value: HighlightNavDestination(highlight: highlight, chapter: chapter)) {
                HighlightRow(highlight: highlight, chapter: chapter)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Navigation Destination

struct HighlightNavDestination: Hashable {
    let highlight: Highlight
    let chapter: HandbookChapter

    var sectionIndex: Int {
        chapter.sections.firstIndex { $0.id == highlight.sectionId } ?? 0
    }

    static func == (lhs: HighlightNavDestination, rhs: HighlightNavDestination) -> Bool {
        lhs.highlight.id == rhs.highlight.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(highlight.id)
    }
}

// MARK: - Highlight Row

struct HighlightRow: View {
    let highlight: Highlight
    let chapter: HandbookChapter

    private var sectionTitle: String {
        chapter.sections.first { $0.id == highlight.sectionId }?.title ?? ""
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
                        .font(HBFont.sans(13, weight: .semibold))
                        .foregroundColor(.hbTextPrimary)
                        .lineLimit(1)

                    // Text preview
                    Text(highlight.textPreview)
                        .font(HBFont.sans(13))
                        .foregroundColor(.hbTextSecondary)
                        .lineSpacing(4)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    // Date
                    Text(relativeDate)
                        .font(HBFont.sans(11))
                        .foregroundColor(.hbTextMuted)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
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
    NavigationStack {
        HighlightsView()
    }
    .modelContainer(for: [Highlight.self])
    .environment(HandbookCatalog(repository: BundleHandbookRepository()))
}
