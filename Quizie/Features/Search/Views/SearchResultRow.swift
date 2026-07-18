import SwiftUI

struct SearchResultRow: View {
    let result: HandbookSearchResult
    let query: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                // Chapter + section breadcrumb
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ChapterTheme.forChapter(result.chapter.id).accent)
                        .frame(width: 3, height: 14)

                    Text(result.chapter.number)
                        .font(HBFont.sans(12, weight: .semibold))
                        .foregroundColor(.hbTextMuted)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.hbTextMuted.opacity(0.5))

                    Text(result.section.title)
                        .font(HBFont.sans(12, weight: .medium))
                        .foregroundColor(ChapterTheme.forChapter(result.chapter.id).accent)
                        .lineLimit(1)
                }

                // Snippet with highlighted match
                highlightedSnippet
                    .font(HBFont.sans(14))
                    .foregroundColor(.hbTextSecondary)
                    .lineSpacing(4)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                // Chapter title
                Text(result.chapter.title)
                    .font(HBFont.sans(12))
                    .foregroundColor(.hbTextMuted)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()
                .padding(.leading, 20)
        }
    }

    private var highlightedSnippet: Text {
        guard let range = result.matchRange,
              range.lowerBound >= result.snippet.startIndex,
              range.upperBound <= result.snippet.endIndex else {
            return Text(result.snippet)
        }

        var attributed = AttributedString(result.snippet)
        if let attrRange = Range(range, in: attributed) {
            attributed[attrRange].font = HBFont.sans(14, weight: .semibold)
            attributed[attrRange].foregroundColor = .hbAccent
        }
        return Text(attributed)
    }
}

#Preview {
    let dependencies = try! AppDependencies.preview()
    SearchView(dependencies: dependencies.search)
}
