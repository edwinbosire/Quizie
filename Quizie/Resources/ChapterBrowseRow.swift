import SwiftUI

struct ChapterBrowseRow: View {
    let chapterNumber: String
    let title: String
    let chapterIndex: Int
    var detail: String? = nil
    let trailingSystemImage: String

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(ChapterTheme.forChapter(chapterIndex).accent)
                .frame(width: 4, height: detail == nil ? 32 : 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(chapterNumber.uppercased())
                    .appFont(.caption2.weight(.semibold))
                    .foregroundColor(.hbTextMuted)

                Text(title)
                    .appFont(.footnote.weight(.medium))
                    .foregroundColor(.hbTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail {
                    Text(detail)
                        .appFont(.caption2)
                        .foregroundColor(.hbTextMuted)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: trailingSystemImage)
                .appFont(.caption.weight(.medium))
                .foregroundColor(.hbTextMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.hbSurface)
        .clipShape(RoundedRectangle(cornerRadius: HBRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: HBRadius.sm)
                .stroke(Color.hbBorder, lineWidth: 1)
        )
    }
}
