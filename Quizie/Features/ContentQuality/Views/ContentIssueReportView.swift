import SwiftUI

struct ContentIssueReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let content: ContentReportContent
    @State private var category = ContentIssueCategory.incorrectAnswer
    @State private var details = ""
    @State private var showsMailError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Content") {
                    LabeledContent("Type", value: content.kind.rawValue)
                    LabeledContent("ID", value: content.contentID)
                    Text(content.prompt)
                        .font(.callout)
                        .foregroundStyle(Color.hbTextSecondary)
                }

                Section("What’s wrong?") {
                    Picker("Issue type", selection: $category) {
                        ForEach(ContentIssueCategory.allCases) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }

                    TextField("Add details (optional)", text: $details, axis: .vertical)
                        .lineLimit(3...7)
                        .accessibilityIdentifier("contentReport.details")
                }

                Section {
                    Label("Your email app will open with the content ID, prompt and configured answer included. You can review everything before sending.", systemImage: "envelope")
                        .font(.footnote)
                        .foregroundStyle(Color.hbTextMuted)
                }
            }
            .navigationTitle("Report an issue")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color.hbBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue to Mail", action: openEmail)
                        .accessibilityIdentifier("contentReport.send")
                }
            }
            .alert("Unable to Open Mail", isPresented: $showsMailError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please email \(ContentReviewSettings.feedbackAddress) and include content ID \(content.contentID).")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func openEmail() {
        guard let url = ContentFeedbackEmail.reportURL(content: content, category: category, details: details) else {
            showsMailError = true
            return
        }
        openURL(url) { accepted in
            if accepted {
                dismiss()
            } else {
                showsMailError = true
            }
        }
    }
}

#Preview {
    ContentIssueReportView(content: ContentReportContent(kind: .question, contentID: "q-102", prompt: "When was Magna Carta agreed?", answerContext: "✓ 1. 1215\n– 2. 1066"))
}
