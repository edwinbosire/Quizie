import SwiftUI

struct ChapterView: View {
    let dependencies: HandbookReaderDependencies
    @State private var chapter: HandbookChapter
    var initialSectionIndex: Int? = nil
    let searchHighlight: String?
    private let initialChapterID: String
    @State private var selectedSectionIndex: Int = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var showContinueReading: Bool = false
    @State private var savedScrollOffset: CGFloat = 0
    @State private var initialLoadComplete: Bool = false
    @State private var presentedSheet: ChapterSheet?
    @AppStorage(ReadingThemeStyle.storageKey) private var themeStyleRaw: String = ReadingThemeStyle.classic.rawValue
    @AppStorage(ReaderTextSize.storageKey) private var readerTextSizeRaw: String = ReaderTextSize.standard.rawValue
    @Environment(\.dismiss) private var dismiss
    private var catalog: HandbookCatalog { dependencies.catalog }
    private var progressLibrary: ReadingProgressLibrary { dependencies.progress }
    private var highlightLibrary: HighlightLibrary { dependencies.highlights }

    private var highlights: [HighlightSnapshot] { highlightLibrary.forChapter(chapter.contentID) }

    init(
        chapter: HandbookChapter,
        dependencies: HandbookReaderDependencies,
        initialSectionIndex: Int? = nil,
        searchHighlight: String? = nil
    ) {
        self._chapter = State(initialValue: chapter)
        self.dependencies = dependencies
        self.initialSectionIndex = initialSectionIndex
        self.searchHighlight = searchHighlight
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
        GeometryReader { geometry in
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
                        VStack(spacing: 24) {
                            ForEach(Array(chapter.sections.enumerated()), id: \.element.id) { idx, section in
                                ReaderSection(
                                    chapter: chapter,
                                    section: section,
                                    sectionIndex: idx,
                                    theme: theme,
                                    chapterID: chapter.contentID,
                                    highlights: highlights.filter { $0.sectionID == section.id },
                                    highlightLibrary: highlightLibrary,
                                    aiInference: dependencies.aiInference,
                                    flashcardMemory: dependencies.flashcardMemory,
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
                        }
                        .padding(.top, 28)
                        .padding(.bottom, 64)
                    }
                }
                .background(readingThemeStyle.background)
                .ignoresSafeArea(edges: .bottom)
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y
                } action: { oldValue, newValue in
                    // contentOffset.y is negative when scrolling down, so negate it to get positive offset
                    let newScrollOffset = abs(newValue)
                    scrollOffset = newScrollOffset
                    
                    // Hide continue reading banner if user scrolls at all (>50px from top)
                    if showContinueReading && newScrollOffset > 50 {
                        withAnimation {
                            showContinueReading = false
                        }
                    }
                }
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentSize.height
                } action: { oldValue, newValue in
                    contentHeight = newValue
                }
                .onChange(of: scrollOffset) { oldValue, newValue in
                    updateReadingProgress()
                }
                .onChange(of: contentHeight) { oldValue, newValue in
                    updateReadingProgress()
                }
                .onChange(of: geometry.size.height) { oldValue, newValue in
                    viewportHeight = newValue
                }
                // Section tab bar pinned above content
                .safeAreaInset(edge: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        // Custom nav bar (matches .top-nav)
                        ChapterNavBar(
                            currentChapter: chapter,
                            dismiss: dismiss,
                            onChooseChapter: { presentedSheet = .chapterPicker },
                            readingTheme: readingTheme
                        )

                        // Scrollable section tabs
                        SectionTabBar(
                            sections: chapter.sections,
                            selectedIndex: $selectedSectionIndex,
                            theme: theme,
                            readingTheme: readingTheme
                        )
                        .onChange(of: selectedSectionIndex) { _, newIdx in
                            withAnimation(.easeInOut(duration: 0.35)) {
                                proxy.scrollTo(chapter.sections[newIdx].id, anchor: .top)
                            }
                        }

                        Divider().background(readingThemeStyle.border)
                    }
                    .background(readingThemeStyle.background.opacity(0.96))
                    .background(.ultraThinMaterial)
                }
                
                    // Continue Reading Banner
                    if showContinueReading {
                        ContinueReadingBanner(
                            progress: savedScrollOffset / max(contentHeight - viewportHeight, 1),
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
            }
        }
    }

    private func prepareChapter(proxy: ScrollViewProxy) async {
        initialLoadComplete = false
        let progress = progressLibrary.start(chapterID: chapter.contentID)

        do {
            try await Task.sleep(for: .milliseconds(50))
        } catch {
            return
        }
        proxy.scrollTo("scrollAnchor", anchor: .top)

        do {
            try await Task.sleep(for: .milliseconds(250))
        } catch {
            return
        }

        if chapter.contentID == initialChapterID,
           let targetIndex = initialSectionIndex,
           chapter.sections.indices.contains(targetIndex) {
            selectedSectionIndex = targetIndex
            withAnimation(.easeInOut(duration: 0.4)) {
                proxy.scrollTo(chapter.sections[targetIndex].id, anchor: .top)
            }
        } else if let progress,
                  progress.isStarted,
                  !progress.isCompleted,
                  progress.scrollOffset > 100 {
            savedScrollOffset = progress.scrollOffset
            withAnimation {
                showContinueReading = true
            }
        }

        do {
            try await Task.sleep(for: .milliseconds(200))
        } catch {
            return
        }
        initialLoadComplete = true
    }
    
    private func updateReadingProgress() {
        guard contentHeight > 0, viewportHeight > 0 else { 
            return 
        }
        
        // Don't update progress until initial load is complete to avoid overwriting saved progress
        guard initialLoadComplete else {
            return
        }
        
        let progress = progressLibrary.progress(for: chapter.contentID)
        
        // Only update if we have meaningful scroll data (>10px) or if progress already exists
        // This prevents overwriting saved progress with 0 on initial load
        if scrollOffset > 10 || (progress?.scrollOffset ?? 0) > 0 {
            progressLibrary.update(chapterID: chapter.contentID, scrollOffset: scrollOffset, contentHeight: contentHeight, viewportHeight: viewportHeight)
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
        scrollOffset = 0
        contentHeight = 0
        showContinueReading = false
        savedScrollOffset = 0
        initialLoadComplete = false

        // Changing the task ID cancels the old preparation work and starts the
        // new chapter's lifecycle-bound setup.
        chapter = newChapter
    }
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

private enum ChapterSheet: String, Identifiable {
    case readerSettings
    case chapterPicker

    var id: String { rawValue }
}

// MARK: - Continue Reading Banner
