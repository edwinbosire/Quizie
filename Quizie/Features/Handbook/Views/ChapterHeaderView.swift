import SwiftUI

struct ChapterHeaderView: View {
    let chapter: HandbookChapter
    let theme: ChapterTheme
    let readingTheme: ReadingTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(chapter.number.uppercased())
                .font(readingTheme.scaledFont(.caption.weight(.bold)))
                .tracking(1.6)
                .foregroundStyle(theme.accent)

            chapterTitle

            Rectangle()
                .fill(theme.accent)
                .frame(width: 56, height: 4)
        }
        .padding(.horizontal, 28)
        .padding(.top, 44)
        .padding(.bottom, 18)
        .frame(maxWidth: 760, alignment: .leading)
        .frame(maxWidth: .infinity)
        .background(readingTheme.style.background)
    }

    private var chapterTitle: some View {
        Text(chapter.title)
            .font(readingTheme.scaledFont(.system(size: 38, weight: .bold, design: .serif)))
            .foregroundColor(readingTheme.style.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("reader.chapterHeader.title")
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
        ChapterView(
            chapter: try! BundleHandbookRepository().document().chapters[0],
            dependencies: dependencies
        )
    }
}
