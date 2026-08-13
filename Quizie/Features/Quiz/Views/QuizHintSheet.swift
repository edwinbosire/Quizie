import SwiftUI

struct QuizHintSheet: View {
    @Environment(\.dismiss) private var dismiss
    let source: QuizQuestionSource

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sourceHeader

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
