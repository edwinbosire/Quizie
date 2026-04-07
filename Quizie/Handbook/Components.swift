import SwiftUI
import SwiftData

// MARK: - Search Highlight Utility

/// Applies a yellow background highlight to all case-insensitive occurrences of `term` within an `AttributedString`.
func applySearchHighlight(to attributed: inout AttributedString, term: String?) {
    guard let term, !term.isEmpty else { return }
    let plain = String(attributed.characters)
    let lowercased = plain.lowercased()
    let lowercasedTerm = term.lowercased()
    var searchStart = lowercased.startIndex
    while let range = lowercased.range(of: lowercasedTerm, range: searchStart..<lowercased.endIndex) {
        if let attrRange = Range(range, in: attributed) {
            attributed[attrRange].backgroundColor = Color.yellow.opacity(0.4)
            attributed[attrRange].foregroundColor = Color.hbTextPrimary
        }
        searchStart = range.upperBound
    }
}

// MARK: - Chapter Badge (pill label at top of chapter)
struct ChapterBadge: View {
    let text: String
    let theme: ChapterTheme

    var body: some View {
        Text(text.uppercased())
            .font(HBFont.sans(11, weight: .semibold))
            .kerning(1.5)
            .foregroundColor(theme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(theme.accentLight)
            .clipShape(Capsule())
    }
}

// MARK: - Section Tab Pill
struct SectionTabPill: View {
    let title: String
    let isActive: Bool
    let theme: ChapterTheme
    @Environment(\.readingTheme) private var readingTheme

    private var rt: ReadingThemeStyle { readingTheme.style }

    var body: some View {
        Text(title)
            .font(HBFont.sans(13, weight: .medium))
            .foregroundColor(isActive ? .white : rt.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(isActive ? theme.accent : rt.surface)
            .overlay(
                Capsule()
                    .stroke(isActive ? theme.accent : rt.border, lineWidth: 1)
            )
            .clipShape(Capsule())
            .animation(.easeInOut(duration: 0.15), value: isActive)
    }
}

// MARK: - Scrollable Section Tab Bar
struct SectionTabBar: View {
    let sections: [HandbookSection]
    @Binding var selectedIndex: Int
    let theme: ChapterTheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(sections.enumerated()), id: \.offset) { idx, section in
                    SectionTabPill(
                        title: section.title,
                        isActive: selectedIndex == idx,
                        theme: theme
                    )
                    .onTapGesture { selectedIndex = idx }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .padding(.bottom, 0)
        }
    }
}

// MARK: - Inline text with **bold** markdown support
struct InlineText: View {
    let raw: String
    let fontSize: CGFloat
    let color: Color?
    @Environment(\.readingTheme) private var readingTheme
    @Environment(\.searchHighlight) private var searchHighlight

    init(_ raw: String, fontSize: CGFloat = 16, color: Color? = nil) {
        self.raw = raw
        self.fontSize = fontSize
        self.color = color
    }

    private var resolvedColor: Color {
        color ?? readingTheme.style.textSecondary
    }

    private var resolvedSize: CGFloat {
        fontSize + readingTheme.fontSizeAdjustment
    }

    var body: some View {
        Text(attributedString)
    }

    var attributedString: AttributedString {
        var result = AttributedString()
        let parts = raw.components(separatedBy: "**")
        for (i, part) in parts.enumerated() {
            var attr = AttributedString(part)
            if i % 2 == 1 {
                attr.font = HBFont.sans(resolvedSize, weight: .semibold)
            } else {
                attr.font = HBFont.sans(resolvedSize)
            }
            attr.foregroundColor = resolvedColor
            result += attr
        }
        applySearchHighlight(to: &result, term: searchHighlight)
        return result
    }
}

// MARK: - Bullet List Row
struct BulletListRow: View {
    let item: BulletItem
    let accentColor: Color
    let isLast: Bool
    @Environment(\.readingTheme) private var readingTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                Text("·")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(accentColor)
                    .frame(width: 22, alignment: .leading)
                    .padding(.top, 1)

                InlineText(item.text.raw, fontSize: 15.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 6)
            }

            if !isLast {
                Divider()
                    .background(readingTheme.style.surface2)
            }
        }
    }
}

// MARK: - Bullet List Block
struct BulletListBlock: View {
    let items: [BulletItem]
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                BulletListRow(item: item, accentColor: accentColor, isLast: idx == items.count - 1)
            }
        }
        .padding(.bottom, 4)
    }
}

// MARK: - Check That You Understand Box
struct CheckUnderstandBox: View {
    let items: [String]
    let theme: ChapterTheme
    @Environment(\.readingTheme) private var readingTheme
    @Environment(\.searchHighlight) private var searchHighlight

    private var fs: CGFloat { readingTheme.fontSizeAdjustment }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("✓")
                    .font(HBFont.sans(11, weight: .semibold))
                    .foregroundColor(theme.accent)
                Text("CHECK THAT YOU UNDERSTAND")
                    .font(HBFont.sans(11, weight: .semibold))
                    .kerning(1.5)
                    .foregroundColor(theme.accent)
            }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .top, spacing: 0) {
                        Text("·")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(theme.accent)
                            .frame(width: 20, alignment: .leading)
                            .padding(.top, 1)
                        Text(highlightedItem(item))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 5)
                    }
                    if idx < items.count - 1 {
                        Divider()
                            .background(theme.accent.opacity(0.12))
                    }
                }
            }
        }
        .padding(16)
        .background(theme.accentLight)
        .overlay(
            RoundedRectangle(cornerRadius: HBRadius.sm)
                .stroke(theme.checkBorderColor, lineWidth: 1)
        )
        .cornerRadius(HBRadius.sm)
        .padding(.top, 8)
    }

    private func highlightedItem(_ item: String) -> AttributedString {
        var attr = AttributedString(item)
        attr.font = HBFont.sans(14 + fs)
        attr.foregroundColor = theme.accent.opacity(0.85)
        applySearchHighlight(to: &attr, term: searchHighlight)
        return attr
    }
}

// MARK: - Blockquote
struct BlockquoteView: View {
    let text: String
    let accentColor: Color
    @Environment(\.readingTheme) private var readingTheme
    @Environment(\.searchHighlight) private var searchHighlight

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 3)
                .cornerRadius(1.5)

            Text(highlightedText)
                .lineSpacing(6 + (readingTheme.fontSizeAdjustment * 0.5))
                .padding(.leading, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(readingTheme.style.surface2)
        }
        .cornerRadius(HBRadius.sm)
        .padding(.vertical, 8)
    }

    private var highlightedText: AttributedString {
        var attr = AttributedString(text)
        attr.font = HBFont.loraItalic(15 + readingTheme.fontSizeAdjustment)
        attr.foregroundColor = readingTheme.style.textSecondary
        applySearchHighlight(to: &attr, term: searchHighlight)
        return attr
    }
}

// MARK: - Section Subheading (h3)
struct SectionSubheading: View {
    let text: String
    let isFirst: Bool
    @Environment(\.readingTheme) private var readingTheme
    @Environment(\.searchHighlight) private var searchHighlight

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !isFirst {
                Divider()
                    .background(readingTheme.style.border)
                    .padding(.bottom, 16)
            }
            Text(highlightedText)
                .padding(.top, isFirst ? 0 : 0)
                .padding(.bottom, 8)
        }
        .padding(.top, isFirst ? 0 : 8)
    }

    private var highlightedText: AttributedString {
        var attr = AttributedString(text)
        attr.font = HBFont.lora(17 + readingTheme.fontSizeAdjustment)
        attr.foregroundColor = readingTheme.style.textPrimary
        applySearchHighlight(to: &attr, term: searchHighlight)
        return attr
    }
}

// MARK: - Section Subheading2 (h4)
struct SectionSubheading2: View {
    let text: String
    @Environment(\.readingTheme) private var readingTheme
    @Environment(\.searchHighlight) private var searchHighlight

    var body: some View {
        Text(highlightedText)
            .kerning(0.5)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }

    private var highlightedText: AttributedString {
        var attr = AttributedString(text.uppercased())
        attr.font = HBFont.sans(13 + readingTheme.fontSizeAdjustment, weight: .semibold)
        attr.foregroundColor = readingTheme.style.textPrimary
        applySearchHighlight(to: &attr, term: searchHighlight)
        return attr
    }
}

// MARK: - Data Table
struct DataTableView: View {
    let headers: [String]
    let rows: [[String]]
    @Environment(\.readingTheme) private var readingTheme
    @Environment(\.searchHighlight) private var searchHighlight

    private var rt: ReadingThemeStyle { readingTheme.style }
    private var fs: CGFloat { readingTheme.fontSizeAdjustment }

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                    Text(highlightedHeader(header))
                        .kerning(0.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }
            }
            .background(rt.surface2)

            Divider().background(rt.border)

            // Data rows
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        Text(highlightedCell(cell))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }
                }
                if rowIdx < rows.count - 1 {
                    Divider().background(rt.border)
                }
            }
        }
        .background(rt.surface)
        .cornerRadius(HBRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: HBRadius.sm)
                .stroke(rt.border, lineWidth: 1)
        )
        .padding(.vertical, 8)
    }

    private func highlightedHeader(_ text: String) -> AttributedString {
        var attr = AttributedString(text.uppercased())
        attr.font = HBFont.sans(12 + fs, weight: .semibold)
        attr.foregroundColor = rt.textPrimary
        applySearchHighlight(to: &attr, term: searchHighlight)
        return attr
    }

    private func highlightedCell(_ text: String) -> AttributedString {
        var attr = AttributedString(text)
        attr.font = HBFont.sans(14 + fs)
        attr.foregroundColor = rt.textSecondary
        applySearchHighlight(to: &attr, term: searchHighlight)
        return attr
    }
}

// MARK: - Section Content Card
struct SectionCard: View {
    let section: HandbookSection
    let theme: ChapterTheme
    var chapterId: Int = 0
    var highlights: [Highlight] = []
    @Environment(\.readingTheme) private var readingTheme

    private var rt: ReadingThemeStyle { readingTheme.style }
    private var fs: CGFloat { readingTheme.fontSizeAdjustment }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title bar
            VStack(alignment: .leading, spacing: 0) {
                Text(section.title)
                    .font(HBFont.lora(20 + fs))
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
                    chapterId: chapterId,
                    sectionId: section.id,
                    highlights: highlights
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
    var chapterId: Int = 0
    var sectionId: String = ""
    var highlights: [Highlight] = []
    @Environment(\.readingTheme) private var readingTheme
    @Environment(\.searchHighlight) private var searchHighlight

    private var rt: ReadingThemeStyle { readingTheme.style }
    private var fs: CGFloat { readingTheme.fontSizeAdjustment }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { idx, block in
                let existing = highlights.first { $0.blockIndex == idx }
                let prev = highlights.first { $0.blockIndex == idx - 1 }
                let next = highlights.first { $0.blockIndex == idx + 1 }

                HighlightableBlock(
                    chapterId: chapterId,
                    sectionId: sectionId,
                    blockIndex: idx,
                    totalBlockCount: blocks.count,
                    block: block,
                    existingHighlight: existing,
                    previousHighlight: prev,
                    nextHighlight: next
                ) {
                    blockView(block, index: idx)
                }
            }
        }
    }

    @ViewBuilder
    func blockView(_ block: ContentBlock, index: Int) -> some View {
        switch block {
        case .paragraph(let text):
            Text(highlightedText(text, font: HBFont.sans(16 + fs), color: rt.textSecondary))
                .lineSpacing(8 + (fs * 0.5))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 14)

        case .subheading(let text):
            SectionSubheading(text: text, isFirst: index == 0)

        case .subheading2(let text):
            SectionSubheading2(text: text)

        case .bulletList(let items):
            BulletListBlock(items: items, accentColor: theme.accent)
                .padding(.bottom, 8)

        case .checkUnderstand(let items):
            CheckUnderstandBox(items: items, theme: theme)
                .padding(.bottom, 4)

        case .blockquote(let text):
            BlockquoteView(text: text, accentColor: theme.accent)

        case .dataTable(let headers, let rows):
            DataTableView(headers: headers, rows: rows)

        }
    }

    private func highlightedText(_ text: String, font: Font, color: Color) -> AttributedString {
        var attr = AttributedString(text)
        attr.font = font
        attr.foregroundColor = color
        applySearchHighlight(to: &attr, term: searchHighlight)
        return attr
    }
}

// MARK: - Home Chapter Card
struct HomeChapterCard: View {
    let chapter: HandbookChapter
    @Query private var allProgress: [ReadingProgress]

    init(chapter: HandbookChapter) {
        self.chapter = chapter
        
        // Filter the query to only get progress for this specific chapter
        let chapterId = chapter.id
        _allProgress = Query(
            filter: #Predicate<ReadingProgress> { progress in
                progress.chapterId == chapterId
            }
        )
    }

    private var theme: ChapterTheme {
        ChapterTheme.forChapter(chapter.id)
    }

    private var cardAccentColors: [Color] = [
        Color(hex: "#1B4F72"), Color(hex: "#1A5276"),
        Color(hex: "#6E2C00"), Color(hex: "#145A32"), Color(hex: "#512E5F")
    ]
    
    private var readingProgress: ReadingProgress? {
        allProgress.first
    }

	var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(chapter.number.uppercased())
                        .font(HBFont.sans(11, weight: .semibold))
                        .kerning(1)
                        .foregroundColor(.hbTextMuted)
                    
                    Spacer()
                    
                    // Progress indicator
                    if let progress = readingProgress {
                        ProgressBadge(progress: progress)
                    }
                }

                Text(chapter.title)
                    .font(HBFont.lora(18))
                    .foregroundColor(.hbTextPrimary)
                    .lineLimit(2)

                // Pill labels and reading time
                HStack(spacing: 8) {
                    FlowLayout(spacing: 6) {
                        ForEach(chapter.pillLabels, id: \.self) { label in
                            Text(label)
                                .font(HBFont.sans(12))
                                .foregroundColor(.hbTextSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(Color.hbSurface2)
                                .overlay(
                                    Capsule().stroke(Color.hbBorder, lineWidth: 1)
                                )
                                .clipShape(Capsule())
                        }
                    }
                    
                    Spacer()
                    
                    // Reading time if available
                    if let progress = readingProgress, progress.totalReadingTime > 60 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10))
                            Text(progress.formattedReadingTime)
                                .font(HBFont.sans(11, weight: .medium))
                        }
                        .foregroundColor(.hbTextMuted)
                    }
                }
            }
            .padding(20)
            
            // Progress bar at bottom if started
            if let progress = readingProgress, progress.isStarted {
                ProgressBar(progress: progress.progress, color: cardAccentColors[min(chapter.id, cardAccentColors.count - 1)])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.hbSurface)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(cardAccentColors[min(chapter.id, cardAccentColors.count - 1)])
                .frame(width: 4)
                .cornerRadius(2)
        }
        .clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: HBRadius.md)
                .stroke(Color.hbBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Progress Badge
struct ProgressBadge: View {
    let progress: ReadingProgress
    
    var body: some View {
        if progress.isCompleted {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                Text("Completed")
                    .font(HBFont.sans(10, weight: .semibold))
            }
            .foregroundColor(Color(hex: "#145A32"))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: "#D5F5E3"))
            .clipShape(Capsule())
        } else if progress.isStarted {
            Text("\(Int(progress.progress * 100))%")
                .font(HBFont.sans(10, weight: .semibold))
                .foregroundColor(Color.hbAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.hbAccentLight)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Progress Bar
struct ProgressBar: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(color.opacity(0.15))
                
                Rectangle()
                    .fill(color)
                    .frame(width: geometry.size.width * progress)
                    .animation(.easeOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Flow Layout (for pill labels)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                height += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}
