import SwiftUI

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
					.frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .top, spacing: 10) {
                        Text("·")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(theme.accent)
                            .padding(.top, 1)
                        Text(highlightedItem(item))
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
