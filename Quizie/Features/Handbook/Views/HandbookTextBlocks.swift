import SwiftUI

struct BlockTextSelectionContext {
    let highlights: [SelectableTextHighlight]
    let isSelectionActive: Bool
    let onSelectionChange: (SelectableTextSelection?, Int) -> Void
    let onHighlight: ([NSRange], HighlightColor) -> Void
    let onCreateFlashcard: ([NSRange]) -> Void
    let onHighlightTap: (SelectableTextSelection, Int) -> Void
}

private struct SelectableBlockText: View {
    let attributedText: AttributedString
    let presentation: ReaderPresentation
    let style: SelectableTextStyle
    let lineSpacing: CGFloat
    let rangeOffset: Int
    let emphasizedRanges: [NSRange]
    let selectionContext: BlockTextSelectionContext

    var body: some View {
        SelectableTextView(
            attributedText: attributedText,
            fontScale: presentation.readingTheme.textSize.scaleFactor,
            lineSpacing: lineSpacing,
            style: style,
            rangeOffset: rangeOffset,
            emphasizedRanges: emphasizedRanges,
            highlights: selectionContext.highlights,
            isSelectionActive: selectionContext.isSelectionActive,
            onSelectionChange: { selection in
                selectionContext.onSelectionChange(selection, rangeOffset)
            },
            onHighlight: selectionContext.onHighlight,
            onCreateFlashcard: selectionContext.onCreateFlashcard,
            onHighlightTap: { selection in
                selectionContext.onHighlightTap(selection, rangeOffset)
            }
        )
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct InlineText: View {
    let raw: String
    let color: Color?
    let presentation: ReaderPresentation
    let rangeOffset: Int
    let selectionContext: BlockTextSelectionContext
    private var readingTheme: ReadingTheme { presentation.readingTheme }
    private var searchHighlight: String? { presentation.searchHighlight }

    init(
        _ raw: String,
        color: Color? = nil,
        presentation: ReaderPresentation,
        rangeOffset: Int,
        selectionContext: BlockTextSelectionContext
    ) {
        self.raw = raw
        self.color = color
        self.presentation = presentation
        self.rangeOffset = rangeOffset
        self.selectionContext = selectionContext
    }

    private var resolvedColor: Color {
        color ?? readingTheme.style.textSecondary
    }

    var body: some View {
        SelectableBlockText(
            attributedText: attributedString,
            presentation: presentation,
            style: .body,
            lineSpacing: 5,
            rangeOffset: rangeOffset,
            emphasizedRanges: emphasizedRanges,
            selectionContext: selectionContext
        )
    }

    var attributedString: AttributedString {
        var result = AttributedString()
        let parts = raw.components(separatedBy: "**")
        for (i, part) in parts.enumerated() {
            var attr = AttributedString(part)
            if i % 2 == 1 {
                attr.font = readingTheme.scaledFont(.body.weight(.semibold))
            } else {
                attr.font = readingTheme.scaledFont(.body)
            }
            attr.foregroundColor = resolvedColor
            result += attr
        }
        applySearchHighlight(to: &result, term: searchHighlight)
        return result
    }

    private var emphasizedRanges: [NSRange] {
        var location = 0
        return raw.components(separatedBy: "**").enumerated().compactMap { index, part in
            defer { location += (part as NSString).length }
            guard index % 2 == 1, !part.isEmpty else { return nil }
            return NSRange(location: location, length: (part as NSString).length)
        }
    }
}

// MARK: - Bullet List Row
struct BulletListRow: View {
    let item: BulletItem
    let accentColor: Color
    let isLast: Bool
    let presentation: ReaderPresentation
    let rangeOffset: Int
    let selectionContext: BlockTextSelectionContext
    private var readingTheme: ReadingTheme { presentation.readingTheme }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                Text("·")
                    .appFont(.headline.weight(.bold))
                    .foregroundColor(accentColor)
                    .frame(width: 22, alignment: .leading)
                    .padding(.top, 1)

                InlineText(
                    item.text.raw,
                    presentation: presentation,
                    rangeOffset: rangeOffset,
                    selectionContext: selectionContext
                )
					.frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            }

            if !isLast {
                Rectangle()
					.fill(readingTheme.style.surface2)
					.frame(maxWidth: .infinity)
					.frame(height: 0.77)
            }
        }
    }
}

// MARK: - Bullet List Block
struct BulletListBlock: View {
    let items: [BulletItem]
    let accentColor: Color
    let presentation: ReaderPresentation
    let selectionContext: BlockTextSelectionContext

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                BulletListRow(
                    item: item,
                    accentColor: accentColor,
                    isLast: idx == items.count - 1,
                    presentation: presentation,
                    rangeOffset: itemOffset(at: idx),
                    selectionContext: selectionContext
                )
            }
        }
        .padding(.bottom, 4)
    }

    private func itemOffset(at index: Int) -> Int {
        items.prefix(index).reduce(0) { offset, item in
            offset + (item.text.raw.removingBoldMarkers as NSString).length + 1
        }
    }
}

// MARK: - Check That You Understand Box
struct CheckUnderstandBox: View {
    let items: [String]
    let theme: ChapterTheme
    let presentation: ReaderPresentation
    let selectionContext: BlockTextSelectionContext
    private var readingTheme: ReadingTheme { presentation.readingTheme }
    private var searchHighlight: String? { presentation.searchHighlight }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("✓")
                    .appFont(.caption2.weight(.semibold))
                    .foregroundColor(theme.accent)

				Text("CHECK THAT YOU UNDERSTAND")
                    .appFont(.caption2.weight(.semibold))
                    .foregroundColor(theme.accent)
					.frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .top, spacing: 10) {
                        Text("·")
                            .appFont(.callout.weight(.bold))
                            .foregroundColor(theme.accent)
                            .padding(.top, 1)
                        SelectableBlockText(
                            attributedText: highlightedItem(item),
                            presentation: presentation,
                            style: .body,
                            lineSpacing: 0,
                            rangeOffset: itemOffset(at: idx),
                            emphasizedRanges: [],
                            selectionContext: selectionContext
                        )
							.frame(maxWidth: .infinity, alignment: .leading)
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
        attr.font = readingTheme.scaledFont(.body)
        attr.foregroundColor = theme.accent.opacity(0.85)
        applySearchHighlight(to: &attr, term: searchHighlight)
        return attr
    }

    private func itemOffset(at index: Int) -> Int {
        items.prefix(index).reduce(0) { $0 + ($1 as NSString).length + 1 }
    }
}

// MARK: - Blockquote
struct BlockquoteView: View {
    let text: String
    let accentColor: Color
    let presentation: ReaderPresentation
    let selectionContext: BlockTextSelectionContext
    private var readingTheme: ReadingTheme { presentation.readingTheme }
    private var searchHighlight: String? { presentation.searchHighlight }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 3)
                .cornerRadius(1.5)

            SelectableBlockText(
                attributedText: highlightedText,
                presentation: presentation,
                style: .serifBodyItalic,
                lineSpacing: 0,
                rangeOffset: 0,
                emphasizedRanges: [],
                selectionContext: selectionContext
            )
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
        attr.font = readingTheme.scaledFont(.system(.body, design: .serif).italic())
        attr.foregroundColor = readingTheme.style.textSecondary
        applySearchHighlight(to: &attr, term: searchHighlight)
        return attr
    }
}

// MARK: - Section Subheading (h3)
struct SectionSubheading: View {
    let text: String
    let isFirst: Bool
    let presentation: ReaderPresentation
    let selectionContext: BlockTextSelectionContext
    private var readingTheme: ReadingTheme { presentation.readingTheme }
    private var searchHighlight: String? { presentation.searchHighlight }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !isFirst {
                Divider()
                    .background(readingTheme.style.border)
                    .padding(.bottom, 16)
            }
            SelectableBlockText(
                attributedText: highlightedText,
                presentation: presentation,
                style: .serifHeadlineSemibold,
                lineSpacing: 0,
                rangeOffset: 0,
                emphasizedRanges: [],
                selectionContext: selectionContext
            )
                .padding(.top, isFirst ? 0 : 0)
                .padding(.bottom, 8)
        }
        .padding(.top, isFirst ? 0 : 8)
    }

    private var highlightedText: AttributedString {
        var attr = AttributedString(text)
        attr.font = readingTheme.scaledFont(.system(.headline, design: .serif, weight: .semibold))
        attr.foregroundColor = readingTheme.style.textPrimary
        applySearchHighlight(to: &attr, term: searchHighlight)
        return attr
    }
}

// MARK: - Section Subheading2 (h4)
struct SectionSubheading2: View {
    let text: String
    let presentation: ReaderPresentation
    let selectionContext: BlockTextSelectionContext
    private var readingTheme: ReadingTheme { presentation.readingTheme }
    private var searchHighlight: String? { presentation.searchHighlight }

    var body: some View {
        SelectableBlockText(
            attributedText: highlightedText,
            presentation: presentation,
            style: .footnoteSemibold,
            lineSpacing: 0,
            rangeOffset: 0,
            emphasizedRanges: [],
            selectionContext: selectionContext
        )
            .padding(.top, 12)
            .padding(.bottom, 4)
    }

    private var highlightedText: AttributedString {
        var attr = AttributedString(text.uppercased())
        attr.font = readingTheme.scaledFont(.footnote.weight(.semibold))
        attr.foregroundColor = readingTheme.style.textPrimary
        applySearchHighlight(to: &attr, term: searchHighlight)
        return attr
    }
}

// MARK: - Data Table
struct DataTableView: View {
    let headers: [String]
    let rows: [[String]]
    let presentation: ReaderPresentation
    let selectionContext: BlockTextSelectionContext
    private var readingTheme: ReadingTheme { presentation.readingTheme }
    private var searchHighlight: String? { presentation.searchHighlight }

    private var rt: ReadingThemeStyle { readingTheme.style }
    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                ForEach(Array(headers.enumerated()), id: \.offset) { index, header in
                    SelectableBlockText(
                        attributedText: highlightedHeader(header),
                        presentation: presentation,
                        style: .captionSemibold,
                        lineSpacing: 0,
                        rangeOffset: textOffset(at: index),
                        emphasizedRanges: [],
                        selectionContext: selectionContext
                    )
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
                    ForEach(Array(row.enumerated()), id: \.offset) { cellIdx, cell in
                        SelectableBlockText(
                            attributedText: highlightedCell(cell),
                            presentation: presentation,
                            style: .footnote,
                            lineSpacing: 0,
                            rangeOffset: textOffset(
                                at: headers.count + rows.prefix(rowIdx).reduce(0) { $0 + $1.count } + cellIdx
                            ),
                            emphasizedRanges: [],
                            selectionContext: selectionContext
                        )
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
        attr.font = readingTheme.scaledFont(.caption.weight(.semibold))
        attr.foregroundColor = rt.textPrimary
        applySearchHighlight(to: &attr, term: searchHighlight)
        return attr
    }

    private func highlightedCell(_ text: String) -> AttributedString {
        var attr = AttributedString(text)
        attr.font = readingTheme.scaledFont(.footnote)
        attr.foregroundColor = rt.textSecondary
        applySearchHighlight(to: &attr, term: searchHighlight)
        return attr
    }

    private func textOffset(at index: Int) -> Int {
        let values = headers + rows.flatMap { $0 }
        return values.prefix(index).reduce(0) { $0 + ($1 as NSString).length + 1 }
    }
}

private extension String {
    var removingBoldMarkers: String {
        replacingOccurrences(of: "**", with: "")
    }
}

// MARK: - Section Content Card
