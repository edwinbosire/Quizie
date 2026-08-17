import SwiftUI

struct QuizHintSheet: View {
    @Environment(\.dismiss) private var dismiss
    let source: QuizQuestionSource
    var showsOpenHandbook = false
    var onOpenHandbook: (QuizQuestionSource) -> Void = { _ in }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sourceHeader

                    if showsOpenHandbook {
                        Button {
                            onOpenHandbook(source)
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "book.closed.fill")
                                Text("Show in Handbook")
                                    .appFont(.callout.weight(.semibold))
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .appFont(.caption.weight(.bold))
                            }
                            .foregroundStyle(Color.hbAccent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.hbAccentLight, in: RoundedRectangle(cornerRadius: HBRadius.sm))
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens the full handbook at this passage")
                        .accessibilityIdentifier("quiz.hint.openHandbook")
                    }

                    if source.hasHint {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("HANDBOOK PASSAGE", systemImage: "text.quote")
                                .appFont(.caption2.weight(.semibold))
                                .foregroundColor(.hbTextMuted)

                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(source.hintBlocks) { block in
                                    hintBlock(block)
                                }
                            }
                            .appFont(.body)
                            .foregroundColor(.hbTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                            .accessibilityIdentifier("quiz.hint.content")
                        }
                        .padding(18)
                        .background(Color.hbSurface)
                        .clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
                        .overlay(RoundedRectangle(cornerRadius: HBRadius.md).stroke(Color.hbBorder, lineWidth: 1))
                    }
                }
                .padding(20)
                .frame(maxWidth: 680, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Color.hbBackground)
            .navigationTitle("Handbook Hint")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: dismiss.callAsFunction)
                }
            }
        }
        .accessibilityIdentifier("quiz.hint")
    }

    @ViewBuilder
    private func hintBlock(_ block: QuizHintBlock) -> some View {
        switch block.content {
        case .paragraph(let text):
            Text(text)
                .accessibilityIdentifier("quiz.hint.passage")
        case .blockquote(let text):
            Text(text)
                .italic()
                .padding(.leading, 12)
                .overlay(alignment: .leading) { Rectangle().fill(Color.hbBorder).frame(width: 3) }
        case .bulletList(let items):
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Text("•")
                            .accessibilityHidden(true)
                        Text(item)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .accessibilityIdentifier("quiz.hint.list")
        case .dataTable(let headers, let rows):
            VStack(alignment: .leading, spacing: 7) {
                if !headers.isEmpty {
                    Text(headers.joined(separator: " · "))
                        .fontWeight(.semibold)
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    Text(row.joined(separator: " · "))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .accessibilityIdentifier("quiz.hint.table")
        }
    }

    private var sourceHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(source.taxonomyLabel)
                .appFont(.headline.weight(.semibold))
                .foregroundColor(.hbTextPrimary)

            Label(source.handbookLocation, systemImage: "book.closed")
                .appFont(.footnote.weight(.medium))

            Label(source.sectionTitle, systemImage: "bookmark")
                .appFont(.footnote)
        }
        .foregroundColor(.hbTextSecondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(source.taxonomyLabel). \(source.handbookLocation). \(source.sectionTitle)")
    }
}
