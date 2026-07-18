import SwiftUI

struct ChapterHeaderView: View {
    let chapter: HandbookChapter
    let theme: ChapterTheme
    let readingTheme: ReadingTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ChapterBadge(text: chapter.number, theme: theme)

            Text(chapter.title)
                .font(HBFont.lora(26 + readingTheme.fontSizeAdjustment))
                .foregroundColor(readingTheme.style.textPrimary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(readingTheme.style.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(readingTheme.style.border)
                .frame(height: 1)
        }
    }
}

#Preview {
    let services = PersistenceServices(attemptStore: InMemoryExamAttemptStore(), progressStore: InMemoryReadingProgressStore(), highlightStore: InMemoryHighlightStore())
    let dependencies = HandbookReaderDependencies(
        catalog: HandbookCatalog(repository: BundleHandbookRepository()),
        progress: services.progress,
        highlights: services.highlights
    )
    NavigationStack {
        ChapterView(
            chapter: try! BundleHandbookRepository().document().chapters[0],
            dependencies: dependencies
        )
    }
}
