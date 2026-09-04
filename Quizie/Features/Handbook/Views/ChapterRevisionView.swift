import SwiftUI

nonisolated struct HandbookSectionRevision: Identifiable, Equatable, Sendable {
    let section: HandbookSection
    let conceptIDs: [String]

    var id: String { section.id }
    var title: String { section.title }
}

struct ChapterRevisionView: View {
    let chapter: HandbookChapter
    let taxonomyTagger: TaxonomyTagResolver
    let performance: PerformanceReportService
    let readingTheme: ReadingTheme
    let theme: ChapterTheme
    let onPractice: (HandbookSectionRevision) -> Void
    let onCreateFlashcards: (HandbookSection) -> Void

    private var revisions: [HandbookSectionRevision] {
        chapter.sections.map { section in
            HandbookSectionRevision(section: section, conceptIDs: taxonomyTagger.conceptIDs(forSectionID: section.id))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("CHAPTER REVISION")
                    .font(readingTheme.scaledFont(.caption.weight(.bold)))
                    .foregroundStyle(theme.accent)
                    .accessibilityIdentifier("handbook.chapterRevision.heading")
                Text("Test what you’ve learned")
                    .font(readingTheme.scaledFont(.title2.weight(.bold)))
                    .foregroundStyle(readingTheme.style.textPrimary)
                Text("Choose a section for focused questions, concise recall cards, and practice performance.")
                    .font(readingTheme.scaledFont(.callout))
                    .foregroundStyle(readingTheme.style.textSecondary)
            }

            ForEach(revisions) { revision in
                HandbookSectionRevisionCard(
                    revision: revision,
                    performance: performance.practiceSummary(conceptIDs: revision.conceptIDs),
                    readingTheme: readingTheme,
                    theme: theme,
                    onPractice: { onPractice(revision) },
                    onCreateFlashcards: { onCreateFlashcards(revision.section) }
                )
            }
        }
        .onAppear { performance.refresh() }
    }
}

private struct HandbookSectionRevisionCard: View {
    let revision: HandbookSectionRevision
    let performance: PracticePerformanceSummary
    let readingTheme: ReadingTheme
    let theme: ChapterTheme
    let onPractice: () -> Void
    let onCreateFlashcards: () -> Void

    private var percentage: String {
        performance.accuracy.map { "\(Int(($0 * 100).rounded()))%" } ?? "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(revision.title)
                    .font(readingTheme.scaledFont(.headline.weight(.semibold)))
                    .foregroundStyle(readingTheme.style.textPrimary)
                Spacer(minLength: 8)
                Text(percentage)
                    .font(readingTheme.scaledFont(.title3.weight(.bold)))
                    .foregroundStyle(performance.accuracy == nil ? readingTheme.style.textMuted : performanceColor)
                    .monospacedDigit()
            }

            if let accuracy = performance.accuracy {
                ProgressView(value: accuracy)
                    .tint(performanceColor)
                Text("\(performance.correctCount) of \(performance.answeredCount) practice questions correct\(trendSuffix)")
                    .font(readingTheme.scaledFont(.caption))
                    .foregroundStyle(readingTheme.style.textSecondary)
            } else {
                Text("No section practice results yet.")
                    .font(readingTheme.scaledFont(.caption))
                    .foregroundStyle(readingTheme.style.textMuted)
            }

            HStack(spacing: 10) {
                Button(action: onPractice) {
                    Label("Practice section", systemImage: "checklist")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .disabled(revision.conceptIDs.isEmpty)
                .accessibilityIdentifier("handbook.revision.practice.\(revision.id)")

                Button(action: onCreateFlashcards) {
                    Label("Flashcards", systemImage: "rectangle.stack.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(theme.accent)
                .accessibilityIdentifier("handbook.revision.flashcards.\(revision.id)")
            }
            .font(readingTheme.scaledFont(.caption.weight(.semibold)))
        }
        .padding(16)
        .background(readingTheme.style.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(readingTheme.style.border) }
    }

    private var performanceColor: Color {
        guard let accuracy = performance.accuracy else { return readingTheme.style.textMuted }
        return accuracy >= 0.75 ? Color(hex: "#16794A") : accuracy >= 0.5 ? Color(hex: "#A66B00") : Color(hex: "#B42318")
    }

    private var trendSuffix: String {
        switch performance.trend {
        case .improving: " · improving"
        case .declining: " · declining"
        case .stable: " · stable"
        case .unknown: ""
        }
    }
}
