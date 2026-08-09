import SwiftUI

struct ReaderSection: View {
    let section: HandbookSection
    let sectionIndex: Int
    let theme: ChapterTheme
    var chapterID: String = ""
    var highlights: [HighlightSnapshot] = []
    let highlightLibrary: HighlightLibrary
    let presentation: ReaderPresentation

    private var readingTheme: ReadingTheme { presentation.readingTheme }

    private var rt: ReadingThemeStyle { readingTheme.style }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
			HStack(alignment: .bottom, spacing: 0.0) {
                Text(String(format: "%02d", sectionIndex + 1))
                    .font(readingTheme.scaledFont(.system(.largeTitle, design: .monospaced, weight: .bold)))
                    .foregroundStyle(theme.accent)
					.padding(.trailing)
                sectionTitle(font: .system(.title2, design: .serif, weight: .bold))

            }
            content
        }
        .sectionRule(color: theme.accent.opacity(0.28), top: 42)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionTitle(font: Font) -> some View {
        Text(section.title)
            .font(readingTheme.scaledFont(font))
            .foregroundColor(rt.textPrimary)
			.frame(maxWidth: .infinity, alignment: .leading)
			.textSelection(.enabled)
    }

    private var content: some View {
        ContentBlocksView(
            blocks: section.blocks,
            theme: theme,
            chapterID: chapterID,
            sectionId: section.id,
            highlights: highlights,
            highlightLibrary: highlightLibrary,
            presentation: presentation
        )
    }
}

private extension View {
    func sectionRule(color: Color, top: CGFloat) -> some View {
        overlay(alignment: .bottom) {
            Rectangle()
                .fill(color)
                .frame(height: 1)
                .offset(y: top)
        }
        .padding(.bottom, top)
    }
}

// MARK: - Content Blocks Renderer
struct ContentBlocksView: View {
    let blocks: [ContentBlock]
    let theme: ChapterTheme
    var chapterID: String = ""
    var sectionId: String = ""
    var highlights: [HighlightSnapshot] = []
    let highlightLibrary: HighlightLibrary
    let presentation: ReaderPresentation

    private var readingTheme: ReadingTheme { presentation.readingTheme }
    private var searchHighlight: String? { presentation.searchHighlight }

    @State private var selection: BlockSelection?
    @State private var nativeTextSelection: NativeTextSelection?
    @State private var blockFrames: [Int: CGRect] = [:]

    private var rt: ReadingThemeStyle { readingTheme.style }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.element.id) { idx, block in
                let blockHighlights = highlights.filter { $0.blockID == block.id }
                let existing = blockHighlights.first
                let prev = idx > 0 ? highlights.first { $0.blockID == blocks[idx - 1].id } : nil
                let next = idx + 1 < blocks.count ? highlights.first { $0.blockID == blocks[idx + 1].id } : nil
                let usesInlineHighlight = isParagraph(block)

                HighlightableBlock(
                    displayIndex: idx,
                    existingHighlight: usesInlineHighlight || selection?.contains(idx) == true ? nil : existing,
                    previousHighlight: prev,
                    nextHighlight: next,
                    isSelected: nativeTextSelection == nil && selection?.contains(idx) == true,
                    isSelectionStart: nativeTextSelection == nil && selection?.startIndex == idx,
                    isSelectionEnd: nativeTextSelection == nil && selection?.endIndex == idx
                ) {
                    blockView(block, index: idx, existingHighlights: blockHighlights)
                }
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: BlockFramePreferenceKey.self,
                            value: [idx: geo.frame(in: .named("blockContent"))]
                        )
                    }
                )
                .overlay(alignment: .topLeading) {
                    if let nativeTextSelection,
                       nativeTextSelection.blockIndex == idx,
                       let selection,
                       !selection.isDragging {
                        GeometryReader { geometry in
                            selectionToolbar(for: selection)
                                .frame(width: geometry.size.width)
                                .position(
                                    x: geometry.size.width / 2,
                                    y: selectionToolbarCenterY(
                                        for: nativeTextSelection.selection.rect,
                                        relativeTo: geometry.frame(in: .global)
                                    )
                                )
                                .transition(.scale(scale: 0.9).combined(with: .opacity))
                        }
                    }
                }
                .zIndex(nativeTextSelection?.blockIndex == idx ? 1 : 0)

                // Legacy multi-block selections still use an in-flow toolbar.
                if nativeTextSelection == nil,
                   let sel = selection,
                   sel.endIndex == idx,
                   !sel.isDragging {
                    selectionToolbar(for: sel)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
        }
        .coordinateSpace(name: "blockContent")
        .onPreferenceChange(BlockFramePreferenceKey.self) { frames in
            blockFrames = frames
        }
    }

    @ViewBuilder
    func blockView(
        _ block: ContentBlock,
        index: Int,
        existingHighlights: [HighlightSnapshot]
    ) -> some View {
        let selectableHighlights: [SelectableTextHighlight] = existingHighlights.reversed().compactMap { highlight in
            guard let range = highlight.selectedRange else { return nil }
            return SelectableTextHighlight(
                range: range,
                color: highlight.highlightColor.backgroundColor
            )
        }
        let selectionContext = BlockTextSelectionContext(
            highlights: selectableHighlights,
            isSelectionActive: selection?.contains(index) == true,
            onSelectionChange: { textSelection, segmentOffset in
                updateSelection(
                    textSelection,
                    for: index,
                    segmentOffset: segmentOffset
                )
            }
        )

        switch block.content {
        case .paragraph(let text):
            SelectableTextView(
                attributedText: highlightedText(
                    text,
                    font: readingTheme.scaledFont(.body),
                    color: rt.textSecondary
                ),
                fontScale: readingTheme.textSize.scaleFactor,
                lineSpacing: 5,
                style: .body,
                rangeOffset: 0,
                emphasizedRanges: [],
                highlights: selectableHighlights,
                isSelectionActive: selectionContext.isSelectionActive,
                onSelectionChange: { textSelection in
                    selectionContext.onSelectionChange(textSelection, 0)
                }
            )
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 18)

        case .subheading(let text):
            SectionSubheading(
                text: text,
                isFirst: index == 0,
                presentation: presentation,
                selectionContext: selectionContext
            )

        case .subheading2(let text):
            SectionSubheading2(
                text: text,
                presentation: presentation,
                selectionContext: selectionContext
            )

        case .bulletList(let items):
            BulletListBlock(
                items: items,
                accentColor: theme.accent,
                presentation: presentation,
                selectionContext: selectionContext
            )
                .padding(.bottom, 8)

        case .checkUnderstand(let items):
            CheckUnderstandBox(
                items: items,
                theme: theme,
                presentation: presentation,
                selectionContext: selectionContext
            )
                .padding(.bottom, 4)

        case .blockquote(let text):
            BlockquoteView(
                text: text,
                accentColor: theme.accent,
                presentation: presentation,
                selectionContext: selectionContext
            )

        case .dataTable(let headers, let rows):
            DataTableView(
                headers: headers,
                rows: rows,
                presentation: presentation,
                selectionContext: selectionContext
            )

        }
    }

    private func highlightedText(_ text: String, font: Font, color: Color) -> AttributedString {
        var attr = AttributedString(text)
        attr.font = font
        attr.foregroundColor = color
        applySearchHighlight(to: &attr, term: searchHighlight)
        return attr
    }

    private func updateSelection(
        _ textSelection: SelectableTextSelection?,
        for blockIndex: Int,
        segmentOffset: Int
    ) {
        withAnimation(.easeOut(duration: 0.2)) {
            if let textSelection {
                nativeTextSelection = NativeTextSelection(
                    blockIndex: blockIndex,
                    segmentOffset: segmentOffset,
                    selection: textSelection
                )
                selection = BlockSelection(
                    anchorIndex: blockIndex,
                    currentIndex: blockIndex,
                    isDragging: false
                )
            } else if nativeTextSelection?.blockIndex == blockIndex,
                      nativeTextSelection?.segmentOffset == segmentOffset {
                nativeTextSelection = nil
                selection = nil
            }
        }
    }

    // MARK: - Selection Gesture

    private func blockSelectionGesture(for blockIdx: Int) -> some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("blockContent")))
            .onChanged { value in
                switch value {
                case .first(true):
                    break
                case .second(true, let drag):
                    if let drag {
                        if selection == nil {
                            nativeTextSelection = nil
                            selection = BlockSelection(
                                anchorIndex: blockIdx,
                                currentIndex: blockIdx,
                                isDragging: true
                            )
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                        if selection?.isDragging == true {
                            let newIndex = resolveBlockIndex(at: drag.location)
                            if newIndex != selection?.currentIndex {
                                selection?.currentIndex = newIndex
                                UISelectionFeedbackGenerator().selectionChanged()
                            }
                        }
                    }
                default:
                    break
                }
            }
            .onEnded { _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    selection?.isDragging = false
                }
            }
    }

    private func resolveBlockIndex(at point: CGPoint) -> Int {
        let sorted = blockFrames.sorted { $0.key < $1.key }
        if let first = sorted.first, point.y < first.value.minY {
            return first.key
        }
        for (index, frame) in sorted {
            if point.y >= frame.minY && point.y <= frame.maxY {
                return index
            }
        }
        return sorted.last?.key ?? 0
    }

    // MARK: - Selection Toolbar

    @ViewBuilder
    private func selectionToolbar(for sel: BlockSelection) -> some View {
        let existingInRange = highlightsIntersectingSelection(sel)
        let hasExisting = !existingInRange.isEmpty
        let initialColor = existingInRange.first?.highlightColor ?? .yellow

        HighlightSelectionToolbar(
            hasExistingHighlights: hasExisting,
            initialColor: initialColor,
            onSave: { color in
                saveHighlights(color: color, range: sel.startIndex...sel.endIndex)
                clearSelection()
            },
            onDelete: {
                deleteHighlights(range: sel.startIndex...sel.endIndex)
                clearSelection()
            },
            onCancel: {
                clearSelection()
            }
        )
    }

    private func clearSelection() {
        withAnimation(.easeOut(duration: 0.2)) {
            nativeTextSelection = nil
            selection = nil
        }
    }

    private func selectionToolbarCenterY(
        for selectionRect: CGRect,
        relativeTo blockFrame: CGRect
    ) -> CGFloat {
        let toolbarHalfHeight: CGFloat = 30
        let spacing: CGFloat = 10
        let spaceNeededAbove = toolbarHalfHeight * 2 + spacing
        let localSelectionRect = selectionRect.offsetBy(
            dx: -blockFrame.minX,
            dy: -blockFrame.minY
        )

        if localSelectionRect.minY >= spaceNeededAbove {
            return localSelectionRect.minY - spacing - toolbarHalfHeight
        }
        return localSelectionRect.maxY + spacing + toolbarHalfHeight
    }

    // MARK: - Save & Delete Highlights

    private func saveHighlights(color: HighlightColor, range: ClosedRange<Int>) {
        for idx in range {
            guard idx < blocks.count else { continue }
            let selectedRange = nativeTextSelection?.blockIndex == idx
                ? nativeTextSelection?.selection.range
                : nil
            let preview = selectedRange.flatMap {
                selectedText(in: blocks[idx].plainText, range: $0)
            } ?? String(blocks[idx].plainText.prefix(80))

            if let selectedRange,
               var existing = highlights.first(where: {
                   $0.blockID == blocks[idx].id && $0.selectedRange == selectedRange
               }) {
                existing.color = color
                existing.textPreview = preview
                existing.rangeLocation = selectedRange.location
                existing.rangeLength = selectedRange.length
                highlightLibrary.upsert(existing)
            } else if selectedRange == nil,
                      var existing = highlights.first(where: {
                          $0.blockID == blocks[idx].id && $0.selectedRange == nil
                      }) {
                existing.color = color
                existing.textPreview = preview
                highlightLibrary.upsert(existing)
            } else {
                let highlight = HighlightSnapshot(
                    chapterID: chapterID,
                    sectionID: sectionId,
                    blockID: blocks[idx].id,
                    color: color,
                    textPreview: preview,
                    rangeLocation: selectedRange?.location,
                    rangeLength: selectedRange?.length
                )
                highlightLibrary.upsert(highlight)
            }
        }
    }

    private func deleteHighlights(range: ClosedRange<Int>) {
        for idx in range {
            guard idx < blocks.count else { continue }
            let selectedRange = nativeTextSelection?.blockIndex == idx
                ? nativeTextSelection?.selection.range
                : nil
            let matches = highlights.filter { highlight in
                guard highlight.blockID == blocks[idx].id else { return false }
                guard let selectedRange else { return true }
                guard let highlightRange = highlight.selectedRange else { return false }
                return rangesOverlap(selectedRange, highlightRange)
            }
            matches.forEach { highlightLibrary.delete(id: $0.id) }
        }
    }

    private func highlightsIntersectingSelection(
        _ selection: BlockSelection
    ) -> [HighlightSnapshot] {
        let selectedIDs = Set(
            blocks[selection.startIndex...min(selection.endIndex, blocks.count - 1)]
                .map(\.id)
        )
        guard let nativeTextSelection else {
            return highlights.filter { selectedIDs.contains($0.blockID) }
        }

        let selectedRange = nativeTextSelection.selection.range
        let blockID = blocks[nativeTextSelection.blockIndex].id
        return highlights.filter { highlight in
            guard highlight.blockID == blockID,
                  let highlightRange = highlight.selectedRange else { return false }
            return rangesOverlap(selectedRange, highlightRange)
        }
    }

    private func rangesOverlap(_ lhs: NSRange, _ rhs: NSRange) -> Bool {
        NSIntersectionRange(lhs, rhs).length > 0
    }

    private func isParagraph(_ block: ContentBlock) -> Bool {
        if case .paragraph = block.content { return true }
        return false
    }

    private func selectedText(in text: String, range: NSRange) -> String? {
        let text = text as NSString
        guard range.location >= 0, NSMaxRange(range) <= text.length else { return nil }
        return text.substring(with: range)
    }
}

private struct NativeTextSelection: Equatable {
    let blockIndex: Int
    let segmentOffset: Int
    let selection: SelectableTextSelection
}

// MARK: - Home Chapter Card
