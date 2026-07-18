import SwiftUI

struct ChapterView: View {
    let dependencies: HandbookReaderDependencies
    @State var chapter: HandbookChapter
    var initialSectionIndex: Int? = nil
    let searchHighlight: String?
    @State private var selectedSectionIndex: Int = 0
    @State private var scrollPosition: String? = nil
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var showContinueReading: Bool = false
    @State private var savedScrollOffset: CGFloat = 0
    @State private var hasRestoredScroll: Bool = false
    @State private var initialLoadComplete: Bool = false
    @State private var showReaderSettings: Bool = false
    @State private var showChapterPicker: Bool = false
    @State private var scrollProxy: ScrollViewProxy?
    @AppStorage("readingThemeStyle") private var themeStyleRaw: String = ReadingThemeStyle.classic.rawValue
    @AppStorage("readingFontSizeAdjustment") private var fontSizeAdjustment: Double = 0
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
    }

    private var readingThemeStyle: ReadingThemeStyle {
        ReadingThemeStyle(rawValue: themeStyleRaw) ?? .classic
    }

    private var readingTheme: ReadingTheme {
        ReadingTheme(style: readingThemeStyle, fontSizeAdjustment: CGFloat(fontSizeAdjustment))
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
                    // Capture proxy for use outside ScrollViewReader
                    Color.clear.frame(width: 0, height: 0)
                        .onAppear { scrollProxy = proxy }
                    ScrollView {
                        VStack(spacing: 0) {
                            // Invisible anchor point for scroll restoration
                            Color.clear.frame(height: 1).id("scrollAnchor")
                            
                            // Chapter Header (matches .chapter-header)
                            ChapterHeaderView(chapter: chapter, theme: theme, readingTheme: readingTheme)

                            // Sticky Tab Bar placeholder (real sticky done via safeAreaInset)
                            Color.clear.frame(height: 0).id("top")

                        // Section content
                        VStack(spacing: 24) {
                            ForEach(Array(chapter.sections.enumerated()), id: \.offset) { idx, section in
                                SectionCard(
                                    section: section,
                                    theme: theme,
                                    chapterID: chapter.contentID,
                                    highlights: highlights.filter { $0.sectionID == section.id },
                                    highlightLibrary: highlightLibrary,
                                    presentation: presentation
                                )
                                    .id(section.id)
                                    .padding(.horizontal, 16)
                                    .onAppear {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            selectedSectionIndex = idx
                                        }
                                    }
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 40)
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
                            showChapterPicker: $showChapterPicker,
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
                .onAppear {
                    // Initialize progress record
                    let progress = progressLibrary.start(chapterID: chapter.contentID)
                    
                    // If launched from search with a specific section, scroll there
                    if let targetIndex = initialSectionIndex,
                       targetIndex < chapter.sections.count {
                        selectedSectionIndex = targetIndex
                        let targetSection = chapter.sections[targetIndex]
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                proxy.scrollTo(targetSection.id, anchor: .top)
                            }
                        }
                    } else {
                        // Check if user has previously read this chapter (>5% and <95%)
                        if let progress, progress.isStarted && !progress.isCompleted && progress.scrollOffset > 100 {
                            savedScrollOffset = progress.scrollOffset
                            // Show banner after a brief delay to avoid animation conflicts
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation {
                                    showContinueReading = true
                                }
                            }
                        }
                    }
                    
                    // Mark initial load as complete after a delay to prevent overwriting progress
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        initialLoadComplete = true
                    }
                }
                .onDisappear {
                    // End reading session when leaving the chapter
                    progressLibrary.end(chapterID: chapter.contentID)
                }
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .overlay(alignment: .bottomTrailing) {
            ReaderToolbar(showReaderSettings: $showReaderSettings)
                .padding(.trailing, 20)
                .padding(.bottom, 0)
        }
        .sheet(isPresented: $showReaderSettings) {
            ReaderSettingsSheet(
                themeStyle: Binding(
                    get: { readingThemeStyle },
                    set: { themeStyleRaw = $0.rawValue }
                ),
                fontSizeAdjustment: Binding(
                    get: { CGFloat(fontSizeAdjustment) },
                    set: { fontSizeAdjustment = Double($0) }
                )
            )
        }
        .sheet(isPresented: $showChapterPicker) {
            ChapterPickerSheet(
                catalog: catalog,
                currentChapter: chapter,
                onChapterSelected: { newChapter in
                    showChapterPicker = false
                    if let proxy = scrollProxy {
                        switchChapter(to: newChapter, proxy: proxy)
                    }
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
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
        
        // Mark that we've restored scroll so we don't reset progress
        hasRestoredScroll = true
        
        // Calculate which section to scroll to based on progress percentage
        let progressPercent = progress.progress
        
        // Determine target section index more accurately
        // Add 1 section to account for the fact that we want to show "where to continue reading"
        // rather than "what was last visible"
        let estimatedSectionIndex = max(0, Int(progressPercent * Double(chapter.sections.count)) - 1)
        let targetIndex = min(max(estimatedSectionIndex, 0), chapter.sections.count - 1)
        
        print("📍 Restoring scroll position:")
        print("   Progress: \(Int(progressPercent * 100))%")
        print("   Target section: \(targetIndex) of \(chapter.sections.count)")
        
        // Scroll to that section with animation
        if targetIndex < chapter.sections.count {
            let targetSection = chapter.sections[targetIndex]
            
            // Use a slight delay to ensure layout is complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    proxy.scrollTo(targetSection.id, anchor: .top)
                }
                
                // Update the selected section index to match
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    selectedSectionIndex = targetIndex
                }
            }
        }
    }

    private func switchChapter(to newChapter: HandbookChapter, proxy: ScrollViewProxy) {
        // End session for current chapter
        progressLibrary.end(chapterID: chapter.contentID)

        // Reset state for new chapter
        selectedSectionIndex = 0
        scrollOffset = 0
        contentHeight = 0
        showContinueReading = false
        hasRestoredScroll = false
        initialLoadComplete = false

        // Switch chapter
        chapter = newChapter

        // Scroll to top
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            proxy.scrollTo("scrollAnchor", anchor: .top)
        }

        // Start session for new chapter
        let progress = progressLibrary.start(chapterID: newChapter.contentID)

        // Check for continue reading
        if let progress, progress.isStarted && !progress.isCompleted && progress.scrollOffset > 100 {
            savedScrollOffset = progress.scrollOffset
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    showContinueReading = true
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            initialLoadComplete = true
        }
    }
}

// MARK: - Continue Reading Banner
