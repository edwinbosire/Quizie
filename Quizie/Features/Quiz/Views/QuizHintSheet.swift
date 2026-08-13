import SwiftUI

struct QuizHintSheet: View {
    @Environment(\.dismiss) private var dismiss
    let source: QuizQuestionSource

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sourceHeader

                    if let passage = source.passage {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("HANDBOOK PASSAGE", systemImage: "text.quote")
                                .appFont(.caption2.weight(.semibold))
                                .foregroundColor(.hbTextMuted)

                            Text(passage)
                                .appFont(.body)
                                .foregroundColor(.hbTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                                .accessibilityIdentifier("quiz.hint.passage")
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
