import SwiftUI
import SwiftData

struct ChapterView: View {
    @State var chapter: HandbookChapter
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
    @Environment(\.modelContext) private var modelContext

    private var readingThemeStyle: ReadingThemeStyle {
        ReadingThemeStyle(rawValue: themeStyleRaw) ?? .classic
    }

    private var readingTheme: ReadingTheme {
        ReadingTheme(style: readingThemeStyle, fontSizeAdjustment: CGFloat(fontSizeAdjustment))
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
                            ChapterHeaderView(chapter: chapter, theme: theme)

                            // Sticky Tab Bar placeholder (real sticky done via safeAreaInset)
                            Color.clear.frame(height: 0).id("top")

                        // Section content
                        VStack(spacing: 24) {
                            ForEach(Array(chapter.sections.enumerated()), id: \.offset) { idx, section in
                                SectionCard(section: section, theme: theme)
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
                            showChapterPicker: $showChapterPicker
                        )

                        // Scrollable section tabs
                        SectionTabBar(
                            sections: chapter.sections,
                            selectedIndex: $selectedSectionIndex,
                            theme: theme
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
                            }
                        )
                        .padding(.top, 12)
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .onAppear {
                    // Initialize progress record
                    let progress = ReadingProgress.getOrCreate(for: chapter.id, in: modelContext)
                    
                    // Start tracking reading session
                    progress.startReadingSession()
                    try? modelContext.save()
                    
                    // Check if user has previously read this chapter (>5% and <95%)
                    if progress.isStarted && !progress.isCompleted && progress.scrollOffset > 100 {
                        savedScrollOffset = progress.scrollOffset
                        // Show banner after a brief delay to avoid animation conflicts
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation {
                                showContinueReading = true
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
                    if let progress = ReadingProgress.fetchProgress(for: chapter.id, in: modelContext) {
                        progress.endReadingSession()
                        try? modelContext.save()
                    }
                }
            }
        }
        .environment(\.readingTheme, readingTheme)
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
        
        let progress = ReadingProgress.getOrCreate(for: chapter.id, in: modelContext)
        
        // Only update if we have meaningful scroll data (>10px) or if progress already exists
        // This prevents overwriting saved progress with 0 on initial load
        if scrollOffset > 10 || progress.scrollOffset > 0 {
            progress.updateProgress(
                scrollOffset: scrollOffset,
                contentHeight: contentHeight,
                viewportHeight: viewportHeight
            )
            
            try? modelContext.save()
        }
    }
    
    private func restoreScrollPosition(proxy: ScrollViewProxy) {
        guard let progress = ReadingProgress.fetchProgress(for: chapter.id, in: modelContext),
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
        if let progress = ReadingProgress.fetchProgress(for: chapter.id, in: modelContext) {
            progress.endReadingSession()
            try? modelContext.save()
        }

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
        let progress = ReadingProgress.getOrCreate(for: newChapter.id, in: modelContext)
        progress.startReadingSession()
        try? modelContext.save()

        // Check for continue reading
        if progress.isStarted && !progress.isCompleted && progress.scrollOffset > 100 {
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
struct ContinueReadingBanner: View {
    let progress: Double
    let onContinue: () -> Void
    let onDismiss: () -> Void
    @Environment(\.readingTheme) private var readingTheme

    private var rt: ReadingThemeStyle { readingTheme.style }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.hbAccent.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "book.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.hbAccent)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text("Continue Reading")
                    .font(HBFont.sans(14, weight: .semibold))
                    .foregroundColor(rt.textPrimary)
                
                Text("Resume from \(Int(progress * 100))% complete")
                    .font(HBFont.sans(12))
                    .foregroundColor(rt.textSecondary)
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                // Dismiss button
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(rt.textMuted)
                        .frame(width: 32, height: 32)
                        .background(rt.surface2)
                        .clipShape(Circle())
                }
                
                // Continue button
                Button {
                    onContinue()
                } label: {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.hbAccent)
                        .clipShape(Circle())
                }
            }
        }
        .padding(16)
        .background(rt.surface)
        .overlay(
            RoundedRectangle(cornerRadius: HBRadius.md)
                .stroke(Color.hbAccent.opacity(0.3), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
        .shadow(color: Color.hbAccent.opacity(0.15), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Reader Toolbar (Floating Action Button)
struct ReaderToolbar: View {
    @Binding var showReaderSettings: Bool

    var body: some View {
        Button {
            showReaderSettings = true
        } label: {
            Image(systemName: "textformat.size")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(Color.hbAccent)
                .clipShape(Circle())
                .shadow(color: Color.hbAccent.opacity(0.4), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Custom Navigation Bar
struct ChapterNavBar: View {
    let currentChapter: HandbookChapter
    let dismiss: DismissAction
    @Binding var showChapterPicker: Bool
    @Environment(\.readingTheme) private var readingTheme

    private var rt: ReadingThemeStyle { readingTheme.style }

    var body: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                    Text("Contents")
                        .font(HBFont.sans(15, weight: .medium))
                }
                .foregroundColor(rt == .night ? .white : .hbAccent)
            }

            Spacer()

            Button {
                showChapterPicker = true
            } label: {
                HStack(spacing: 4) {
                    Text(currentChapter.number)
                        .font(HBFont.sans(14, weight: .semibold))
                        .foregroundColor(rt.textMuted)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(rt.textMuted)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Chapter Picker Sheet
struct ChapterPickerSheet: View {
    let currentChapter: HandbookChapter
    let onChapterSelected: (HandbookChapter) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(HandbookData.chapters) { chapter in
                Button {
                    if chapter.id != currentChapter.id {
                        onChapterSelected(chapter)
                    } else {
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 12) {
                        // Accent bar
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ChapterTheme.forChapter(chapter.id).accent)
                            .frame(width: 4, height: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(chapter.number.uppercased())
                                .font(HBFont.sans(11, weight: .semibold))
                                .kerning(1)
                                .foregroundColor(.hbTextMuted)

                            Text(chapter.title)
                                .font(HBFont.sans(15, weight: .medium))
                                .foregroundColor(.hbTextPrimary)
                                .lineLimit(2)
                        }

                        Spacer()

                        if chapter.id == currentChapter.id {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.hbAccent)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(HBFont.sans(15, weight: .semibold))
                }
            }
        }
    }
}

// MARK: - Chapter Header
struct ChapterHeaderView: View {
    let chapter: HandbookChapter
    let theme: ChapterTheme
    @Environment(\.readingTheme) private var readingTheme

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
    NavigationStack {
        ChapterView(chapter: HandbookData.chapters[0])
    }
    .modelContainer(for: [ReadingProgress.self, ExamAttempt.self])
}
