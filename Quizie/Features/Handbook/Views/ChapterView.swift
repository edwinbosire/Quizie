import SwiftUI

struct ChapterView: View {
    let dependencies: HandbookReaderDependencies
    @State private var chapter: HandbookChapter
    var initialSectionIndex: Int? = nil
    var initialBlockID: String? = nil
    let searchHighlight: String?
    let isPresentedModally: Bool
    private let initialChapterID: String
    @State private var selectedSectionIndex: Int = 0
    @State private var scrollMetrics = ChapterScrollMetrics()
    @State private var showContinueReading: Bool = false
    @State private var savedProgress: Double = 0
    @State private var initialLoadComplete: Bool = false
    @State private var presentedSheet: ChapterSheet?
    @State private var revisionPractice: HandbookRevisionPractice?
    @AppStorage(ReadingThemeStyle.storageKey) private var themeStyleRaw: String = ReadingThemeStyle.classic.rawValue
    @AppStorage(ReaderTextSize.storageKey) private var readerTextSizeRaw: String = ReaderTextSize.standard.rawValue
    @Environment(\.dismiss) private var dismiss
    private var catalog: HandbookCatalog { dependencies.catalog }
    private var progressLibrary: ReadingProgressLibrary { dependencies.progress }
    private var highlightLibrary: HighlightLibrary { dependencies.highlights }

    init(
        chapter: HandbookChapter,
        dependencies: HandbookReaderDependencies,
        initialSectionIndex: Int? = nil,
        initialBlockID: String? = nil,
        searchHighlight: String? = nil,
        isPresentedModally: Bool = false
    ) {
        self._chapter = State(initialValue: chapter)
        self.dependencies = dependencies
        self.initialSectionIndex = initialSectionIndex
        self.initialBlockID = initialBlockID
        self.searchHighlight = searchHighlight
        self.isPresentedModally = isPresentedModally
        self.initialChapterID = chapter.contentID
        self._readerTextSizeRaw = AppStorage(
            wrappedValue: ReaderTextSize.loadAndMigrate().rawValue,
            ReaderTextSize.storageKey
        )
    }

    private var readingThemeStyle: ReadingThemeStyle {
        ReadingThemeStyle(rawValue: themeStyleRaw) ?? .classic
    }

    private var readingTheme: ReadingTheme {
        ReadingTheme(
            style: readingThemeStyle,
            textSize: ReaderTextSize(rawValue: readerTextSizeRaw) ?? .standard
        )
    }

    private var presentation: ReaderPresentation {
        ReaderPresentation(readingTheme: readingTheme, searchHighlight: searchHighlight)
    }

    var theme: ChapterTheme {
        ChapterTheme.forChapter(chapter.id)
    }

    var body: some View {
        let highlightsBySection = Dictionary(grouping: highlightLibrary.forChapter(chapter.contentID), by: \.sectionID)

        ScrollViewReader { proxy in
                ZStack(alignment: .top) {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Invisible anchor point for scroll restoration
                            Color.clear.frame(height: 1).id("scrollAnchor")
                            
                            // Chapter Header (matches .chapter-header)
                            ChapterHeaderView(
                                chapter: chapter,
                                theme: theme,
                                readingTheme: readingTheme
                            )

                            // Sticky Tab Bar placeholder (real sticky done via safeAreaInset)
                            Color.clear.frame(height: 0).id("top")

                        // Section content
                        LazyVStack(spacing: 24) {
                            ForEach(Array(chapter.sections.enumerated()), id: \.element.id) { idx, section in
                                ReaderSection(
                                    chapter: chapter,
                                    section: section,
                                    sectionIndex: idx,
                                    theme: theme,
                                    chapterID: chapter.contentID,
                                    highlights: highlightsBySection[section.id] ?? [],
                                    highlightLibrary: highlightLibrary,
                                    aiInference: dependencies.aiInference,
                                    flashcardMemory: dependencies.flashcardMemory,
                                    taxonomyTagger: dependencies.taxonomyTagger,
                                    presentation: presentation
                                )
                                    .id(section.id)
                                    .padding(.horizontal, 28)
                                    .frame(maxWidth: 760)
                                    .frame(maxWidth: .infinity)
                                    .onAppear {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            selectedSectionIndex = idx
                                        }
                                    }
                            }

                            if let revision = dependencies.revision {
                                ChapterRevisionView(
                                    chapter: chapter,
                                    taxonomyTagger: dependencies.taxonomyTagger,
                                    performance: revision.performance,
                                    readingTheme: readingTheme,
                                    theme: theme,
                                    onPractice: startRevisionPractice,
                                    onCreateFlashcards: createRevisionFlashcards
                                )
                                .id("chapter-revision")
                                .padding(.horizontal, 20)
                                .frame(maxWidth: 820)
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.top, 28)
                        .padding(.bottom, 64)
                    }
                }
                .background(readingThemeStyle.background)
                .ignoresSafeArea(edges: .bottom)
                .onScrollGeometryChange(for: ChapterScrollGeometry.self) { geometry in
                    ChapterScrollGeometry(scrollOffset: abs(geometry.contentOffset.y), contentHeight: geometry.contentSize.height, viewportHeight: geometry.containerSize.height)
                } action: { _, newValue in
                    scrollMetrics.current = newValue
                }
                .onScrollPhaseChange { _, newPhase in
                    if newPhase != .idle, showContinueReading {
                        withAnimation {
                            showContinueReading = false
                        }
                    }
                    if newPhase == .idle {
                        updateReadingProgress()
                    }
                }
                // Section tab bar pinned above content
                .safeAreaInset(edge: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        // Custom nav bar (matches .top-nav)
                        ChapterNavBar(
                            currentChapter: chapter,
                            dismiss: dismiss,
                            onChooseChapter: { presentedSheet = .chapterPicker },
                            readingTheme: readingTheme,
                            isPresentedModally: isPresentedModally
                        )

                        // Scrollable section tabs
                        SectionTabBar(
                            sections: chapter.sections,
                            selectedIndex: sectionSelection(proxy: proxy),
                            theme: theme,
                            readingTheme: readingTheme
                        )

                        Divider().background(readingThemeStyle.border)
                    }
                    .background(readingThemeStyle.background.opacity(0.96))
                    .background(.ultraThinMaterial)
                }
                
                    // Continue Reading Banner
                    if showContinueReading {
                        ContinueReadingBanner(
                            progress: savedProgress,
                            onContinue: {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    showContinueReading = false
                                }
                                // Scroll to approximate section based on saved progress
                                restoreScrollPosition(proxy: proxy)
                            },
                            onDismiss: {
                                withAnimation {
                                    showContinueReading = false
                                }
                            },
                            readingTheme: readingTheme
                        )
                        .padding(.top, 12)
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .task(id: chapter.contentID) {
                    await prepareChapter(proxy: proxy)
                }
                .onDisappear {
                    // End reading session when leaving the chapter
                    progressLibrary.end(chapterID: chapter.contentID)
                }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .overlay(alignment: .bottomTrailing) {
            ReaderToolbar(onOpenSettings: { presentedSheet = .readerSettings })
                .padding(.trailing, 20)
                .padding(.bottom, 0)
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .readerSettings:
                ReaderSettingsSheet(
                    themeStyle: Binding(
                        get: { readingThemeStyle },
                        set: { themeStyleRaw = $0.rawValue }
                    ),
                    textSize: Binding(
                        get: { ReaderTextSize(rawValue: readerTextSizeRaw) ?? .standard },
                        set: { readerTextSizeRaw = $0.rawValue }
                    )
                )
            case .chapterPicker:
                ChapterPickerSheet(
                    catalog: catalog,
                    currentChapter: chapter,
                    onChapterSelected: { newChapter in
                        presentedSheet = nil
                        switchChapter(to: newChapter)
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            case .revisionFlashcards(let presentation):
                GeneratedFlashcardPreviewView(presentation: presentation, aiInference: dependencies.aiInference, memory: dependencies.flashcardMemory)
            }
        }
        .fullScreenCover(item: $revisionPractice, onDismiss: refreshRevisionPerformance) { practice in
            if let revision = dependencies.revision {
                QuizRootView(
                    dependencies: revision.quiz,
                    flashcardDependencies: revision.flashcards,
                    handbookDependencies: dependencies,
                    initialTargetConceptIDs: practice.conceptIDs,
                    initialTargetSectionID: practice.sectionID,
                    initialTargetQuestionCount: 10,
                    configuration: .practice,
                    onReturnHome: closeRevisionPractice,
                    onQuitQuiz: closeRevisionPractice
                )
            }
        }
    }

    private func prepareChapter(proxy: ScrollViewProxy) async {
        initialLoadComplete = false
        let progress = progressLibrary.progress(for: chapter.contentID)
        proxy.scrollTo("scrollAnchor", anchor: .top)
        await Task.yield()

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestChapterRevision"), dependencies.revision != nil {
            selectedSectionIndex = max(chapter.sections.count - 1, 0)
            proxy.scrollTo("chapter-revision", anchor: .top)
            initialLoadComplete = true
            await Task.yield()
            _ = progressLibrary.start(chapterID: chapter.contentID)
            return
        }
        #endif

        if chapter.contentID == initialChapterID,
           let initialBlockID,
           let targetIndex = chapter.sections.firstIndex(where: { section in section.blocks.contains(where: { $0.id == initialBlockID }) }) {
            selectedSectionIndex = targetIndex
            proxy.scrollTo(chapter.sections[targetIndex].id, anchor: .top)
            await Task.yield()
            proxy.scrollTo(initialBlockID, anchor: .center)
        } else if chapter.contentID == initialChapterID,
                  let targetIndex = initialSectionIndex,
                  chapter.sections.indices.contains(targetIndex) {
            selectedSectionIndex = targetIndex
            proxy.scrollTo(chapter.sections[targetIndex].id, anchor: .top)
        } else if let progress,
                  progress.isStarted,
                  !progress.isCompleted,
                  progress.scrollOffset > 100 {
            savedProgress = progress.progress
            withAnimation {
                showContinueReading = true
            }
        }

        initialLoadComplete = true
        await Task.yield()
        _ = progressLibrary.start(chapterID: chapter.contentID)
    }

    private func sectionSelection(proxy: ScrollViewProxy) -> Binding<Int> {
        Binding(
            get: { selectedSectionIndex },
            set: { index in
                guard chapter.sections.indices.contains(index) else { return }
                selectedSectionIndex = index
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(chapter.sections[index].id, anchor: .top)
                }
            }
        )
    }

    private func startRevisionPractice(_ revision: HandbookSectionRevision) {
        guard !revision.conceptIDs.isEmpty else { return }
        revisionPractice = HandbookRevisionPractice(sectionID: revision.id, conceptIDs: revision.conceptIDs)
    }

    private func createRevisionFlashcards(_ section: HandbookSection) {
        guard let lastBlockIndex = section.blocks.indices.last,
              let context = FlashcardGenerationContextBuilder.make(chapter: chapter, section: section, selectedBlockRange: 0...lastBlockIndex, taxonomyTagger: dependencies.taxonomyTagger) else { return }
        presentedSheet = .revisionFlashcards(FlashcardGenerationPresentation(context: context, chapterNumber: chapter.id + 1))
    }

    private func closeRevisionPractice() {
        refreshRevisionPerformance()
        revisionPractice = nil
    }

    private func refreshRevisionPerformance() {
        dependencies.revision?.performance.refresh(force: true)
    }
    
    private func updateReadingProgress() {
        let metrics = scrollMetrics.current
        guard metrics.contentHeight > 0, metrics.viewportHeight > 0 else { return }
        
        // Don't update progress until initial load is complete to avoid overwriting saved progress
        guard initialLoadComplete else {
            return
        }
        
        let progress = progressLibrary.progress(for: chapter.contentID)
        
        // Only update if we have meaningful scroll data (>10px) or if progress already exists
        // This prevents overwriting saved progress with 0 on initial load
        if metrics.scrollOffset > 10 || (progress?.scrollOffset ?? 0) > 0 {
            progressLibrary.update(chapterID: chapter.contentID, scrollOffset: metrics.scrollOffset, contentHeight: metrics.contentHeight, viewportHeight: metrics.viewportHeight)
        }
    }
    
    private func restoreScrollPosition(proxy: ScrollViewProxy) {
        guard let progress = progressLibrary.progress(for: chapter.contentID),
              progress.scrollOffset > 0,
              progress.contentHeight > 0 else {
            return
        }
        
        // Calculate which section to scroll to based on progress percentage
        let progressPercent = progress.progress
        
        // Determine target section index more accurately
        // Add 1 section to account for the fact that we want to show "where to continue reading"
        // rather than "what was last visible"
        let estimatedSectionIndex = max(0, Int(progressPercent * Double(chapter.sections.count)) - 1)
        let targetIndex = min(max(estimatedSectionIndex, 0), chapter.sections.count - 1)
        
        if chapter.sections.indices.contains(targetIndex) {
            let targetSection = chapter.sections[targetIndex]
            withAnimation(.easeInOut(duration: 0.6)) {
                proxy.scrollTo(targetSection.id, anchor: .top)
                selectedSectionIndex = targetIndex
            }
        }
    }

    private func switchChapter(to newChapter: HandbookChapter) {
        // End session for current chapter
        progressLibrary.end(chapterID: chapter.contentID)

        // Reset state for new chapter
        selectedSectionIndex = 0
        scrollMetrics.reset()
        showContinueReading = false
        savedProgress = 0
        initialLoadComplete = false

        // Changing the task ID cancels the old preparation work and starts the
        // new chapter's lifecycle-bound setup.
        chapter = newChapter
    }
}

private struct ChapterScrollGeometry: Equatable {
    let scrollOffset: CGFloat
    let contentHeight: CGFloat
    let viewportHeight: CGFloat

    static let zero = ChapterScrollGeometry(scrollOffset: 0, contentHeight: 0, viewportHeight: 0)
}

private final class ChapterScrollMetrics {
    var current = ChapterScrollGeometry.zero
    func reset() { current = .zero }
}

#Preview("Chapter Reader") {
    let dependencies = try! AppDependencies.preview()

    NavigationStack {
        ChapterView(
            chapter: dependencies.handbook.catalog.chapters[0],
            dependencies: dependencies.handbook.reader
        )
    }
}

private enum ChapterSheet: Identifiable {
    case readerSettings
    case chapterPicker
    case revisionFlashcards(FlashcardGenerationPresentation)

    var id: String {
        switch self {
        case .readerSettings: "reader-settings"
        case .chapterPicker: "chapter-picker"
        case .revisionFlashcards(let presentation): "revision-flashcards-\(presentation.id)"
        }
    }
}

private struct HandbookRevisionPractice: Identifiable {
    let sectionID: String
    let conceptIDs: [String]

    var id: String { sectionID }
}

// MARK: - Continue Reading Banner
