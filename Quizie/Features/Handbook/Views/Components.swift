import SwiftUI

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
