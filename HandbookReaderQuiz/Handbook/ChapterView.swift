import SwiftUI
import SwiftData

struct ChapterView: View {
    let chapter: HandbookChapter
    @State private var selectedSectionIndex: Int = 0
    @State private var scrollPosition: String? = nil
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var showContinueReading: Bool = false
    @State private var savedScrollOffset: CGFloat = 0
    @State private var hasRestoredScroll: Bool = false
    @State private var initialLoadComplete: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

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
                .background(Color.hbBackground)
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
                        ChapterNavBar(title: chapter.number, dismiss: dismiss)

                        // Scrollable section tabs
                        SectionTabBar(
                            sections: chapter.sections,
                            selectedIndex: $selectedSectionIndex,
                            theme: theme
                        )
                        .background(Color.hbBackground.opacity(0.95))
                        .onChange(of: selectedSectionIndex) { _, newIdx in
                            withAnimation(.easeInOut(duration: 0.35)) {
                                proxy.scrollTo(chapter.sections[newIdx].id, anchor: .top)
                            }
                        }

                        Divider().background(Color.hbBorder)
                    }
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
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
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
}

// MARK: - Continue Reading Banner
struct ContinueReadingBanner: View {
    let progress: Double
    let onContinue: () -> Void
    let onDismiss: () -> Void
    
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
                    .foregroundColor(.hbTextPrimary)
                
                Text("Resume from \(Int(progress * 100))% complete")
                    .font(HBFont.sans(12))
                    .foregroundColor(.hbTextSecondary)
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
                        .foregroundColor(.hbTextMuted)
                        .frame(width: 32, height: 32)
                        .background(Color.hbSurface2)
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
        .background(Color.hbSurface)
        .overlay(
            RoundedRectangle(cornerRadius: HBRadius.md)
                .stroke(Color.hbAccent.opacity(0.3), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
        .shadow(color: Color.hbAccent.opacity(0.15), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Custom Navigation Bar
struct ChapterNavBar: View {
    let title: String
    let dismiss: DismissAction

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
                .foregroundColor(.hbAccent)
            }

            Spacer()

            Text(title)
                .font(HBFont.sans(14, weight: .semibold))
                .foregroundColor(.hbTextMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Chapter Header
struct ChapterHeaderView: View {
    let chapter: HandbookChapter
    let theme: ChapterTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ChapterBadge(text: chapter.number, theme: theme)

            Text(chapter.title)
                .font(HBFont.lora(26))
                .foregroundColor(.hbTextPrimary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.hbSurface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.hbBorder)
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
