import SwiftUI

struct ChapterPickerSheet: View {
    let catalog: HandbookCatalog
    let currentChapter: HandbookChapter
    let onChapterSelected: (HandbookChapter) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(catalog.chapters) { chapter in
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
