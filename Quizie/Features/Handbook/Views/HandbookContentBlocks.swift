import SwiftUI

struct SectionCard: View {
    let section: HandbookSection
    let theme: ChapterTheme
    var chapterID: String = ""
    var highlights: [HighlightSnapshot] = []
    let highlightLibrary: HighlightLibrary
    let presentation: ReaderPresentation

    private var readingTheme: ReadingTheme { presentation.readingTheme }

    private var rt: ReadingThemeStyle { readingTheme.style }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title bar
            VStack(alignment: .leading, spacing: 0) {
                Text(section.title)
                    .font(readingTheme.scaledFont(.system(.title3, design: .serif, weight: .semibold)))
                    .foregroundColor(rt.textPrimary)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rt.surface)
            .overlay(alignment: .bottom) {
                Rectangle().fill(rt.border).frame(height: 1)
            }

            // Content
            VStack(alignment: .leading, spacing: 0) {
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
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .background(rt.surface)
        }
        .clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: HBRadius.md)
                .stroke(rt.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.07), radius: 6, x: 0, y: 2)
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
    @State private var blockFrames: [Int: CGRect] = [:]

    private var rt: ReadingThemeStyle { readingTheme.style }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.element.id) { idx, block in
                let existing = highlights.first { $0.blockID == block.id }
                let prev = idx > 0 ? highlights.first { $0.blockID == blocks[idx - 1].id } : nil
                let next = idx + 1 < blocks.count ? highlights.first { $0.blockID == blocks[idx + 1].id } : nil

                HighlightableBlock(
                    displayIndex: idx,
                    existingHighlight: selection?.contains(idx) == true ? nil : existing,
                    previousHighlight: prev,
                    nextHighlight: next,
                    isSelected: selection?.contains(idx) ?? false,
                    isSelectionStart: selection?.startIndex == idx,
                    isSelectionEnd: selection?.endIndex == idx
                ) {
                    blockView(block, index: idx)
                }
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: BlockFramePreferenceKey.self,
                            value: [idx: geo.frame(in: .named("blockContent"))]
                        )
                    }
                )
//                .simultaneousGesture(blockSelectionGesture(for: idx))

                // Inline toolbar after the last selected block
                if let sel = selection, sel.endIndex == idx, !sel.isDragging {
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
    func blockView(_ block: ContentBlock, index: Int) -> some View {
        switch block.content {
        case .paragraph(let text):
            Text(highlightedText(text, font: readingTheme.scaledFont(.body), color: rt.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 14)

        case .subheading(let text):
            SectionSubheading(text: text, isFirst: index == 0, presentation: presentation)

        case .subheading2(let text):
            SectionSubheading2(text: text, presentation: presentation)

        case .bulletList(let items):
            BulletListBlock(items: items, accentColor: theme.accent, presentation: presentation)
                .padding(.bottom, 8)

        case .checkUnderstand(let items):
            CheckUnderstandBox(items: items, theme: theme, presentation: presentation)
                .padding(.bottom, 4)

        case .blockquote(let text):
            BlockquoteView(text: text, accentColor: theme.accent, presentation: presentation)

        case .dataTable(let headers, let rows):
            DataTableView(headers: headers, rows: rows, presentation: presentation)

        }
    }

    private func highlightedText(_ text: String, font: Font, color: Color) -> AttributedString {
        var attr = AttributedString(text)
        attr.font = font
        attr.foregroundColor = color
        applySearchHighlight(to: &attr, term: searchHighlight)
        return attr
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
        let selectedIDs = Set(blocks[sel.startIndex...min(sel.endIndex, blocks.count - 1)].map(\.id))
        let existingInRange = highlights.filter { selectedIDs.contains($0.blockID) }
        let hasExisting = !existingInRange.isEmpty
        let initialColor = existingInRange.first?.highlightColor ?? .yellow

        HighlightSelectionToolbar(
            hasExistingHighlights: hasExisting,
            initialColor: initialColor,
            onSave: { color in
                saveHighlights(color: color, range: sel.startIndex...sel.endIndex)
                withAnimation(.easeOut(duration: 0.2)) {
                    selection = nil
                }
            },
            onDelete: {
                deleteHighlights(range: sel.startIndex...sel.endIndex)
                withAnimation(.easeOut(duration: 0.2)) {
                    selection = nil
                }
            },
            onCancel: {
                withAnimation(.easeOut(duration: 0.2)) {
                    selection = nil
                }
            }
        )
    }

    // MARK: - Save & Delete Highlights

    private func saveHighlights(color: HighlightColor, range: ClosedRange<Int>) {
        for idx in range {
            guard idx < blocks.count else { continue }
            if var existing = highlights.first(where: { $0.blockID == blocks[idx].id }) {
                existing.color = color
                highlightLibrary.upsert(existing)
            } else {
                let preview = String(blocks[idx].plainText.prefix(80))
                let highlight = HighlightSnapshot(
                    chapterID: chapterID,
                    sectionID: sectionId,
                    blockID: blocks[idx].id,
                    color: color,
                    textPreview: preview
                )
                highlightLibrary.upsert(highlight)
            }
        }
    }

    private func deleteHighlights(range: ClosedRange<Int>) {
        for idx in range {
            if idx < blocks.count, let existing = highlights.first(where: { $0.blockID == blocks[idx].id }) {
                highlightLibrary.delete(id: existing.id)
            }
        }
    }
}

// MARK: - Home Chapter Card
