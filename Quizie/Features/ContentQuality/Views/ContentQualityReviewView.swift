import SwiftUI

struct ContentQualityReviewView: View {
    @Environment(\.openURL) private var openURL
    let analysis: ContentQualityAnalysis
    @State private var selectedArea: ContentQualityArea?
    @State private var showsMailError = false

    private var visibleFindings: [ContentQualityFinding] {
        guard let selectedArea else { return analysis.findings }
        return analysis.findings.filter { $0.area == selectedArea }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: analysis.findings.isEmpty ? "checkmark.shield.fill" : "checkmark.shield")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(Color.hbAccent)
                    Text(analysis.findings.isEmpty ? "Automated checks passed" : "\(analysis.findings.count) findings to review")
                        .appFont(.system(.title2, design: .serif, weight: .semibold))
                        .foregroundStyle(Color.hbTextPrimary)
                    Text("Every bundled question, guide flashcard and handbook block was checked for structural and recall-quality problems.")
                        .appFont(.callout)
                        .foregroundStyle(Color.hbTextMuted)
                }
                .padding(.vertical, 8)
            }

            Section("Coverage") {
                coverageRow(area: .questions, count: analysis.questionCount, unit: "questions")
                coverageRow(area: .flashcards, count: analysis.flashcardCount, unit: "guide cards")
                coverageRow(area: .handbook, count: analysis.handbookBlockCount, unit: "content blocks")
            }

            Section {
                Picker("Filter", selection: $selectedArea) {
                    Text("All").tag(ContentQualityArea?.none)
                    ForEach(ContentQualityArea.allCases, id: \.self) { area in
                        Text(area.rawValue).tag(Optional(area))
                    }
                }
                .pickerStyle(.menu)
            }

            Section {
                if visibleFindings.isEmpty {
                    Label("No automated findings in this category", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color(hex: "#145A32"))
                } else {
                    ForEach(visibleFindings) { finding in
                        ContentQualityFindingRow(finding: finding)
                    }
                }
            } header: {
                Text("Findings (\(visibleFindings.count))")
            } footer: {
                Text("Automated analysis cannot confirm whether a fact is true or current. Complete a manual editorial review of factual findings before release.")
            }
        }
        .navigationTitle("Quality analysis")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Color.hbBackground)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: emailAnalysis) {
                    Label("Email summary", systemImage: "envelope")
                }
                .accessibilityIdentifier("contentQuality.email")
            }
        }
        .alert("Unable to Open Mail", isPresented: $showsMailError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please email the analysis to \(ContentReviewSettings.feedbackAddress).")
        }
        .accessibilityIdentifier("contentQuality.dashboard")
    }

    private func coverageRow(area: ContentQualityArea, count: Int, unit: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: area.systemImage)
                .foregroundStyle(Color.hbAccent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(area.rawValue)
                    .foregroundStyle(Color.hbTextPrimary)
                Text("\(count) \(unit) checked")
                    .font(.caption)
                    .foregroundStyle(Color.hbTextMuted)
            }
            Spacer()
            let findingCount = analysis.findingCount(for: area)
            Text(findingCount == 0 ? "Passed" : "\(findingCount)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(findingCount == 0 ? Color(hex: "#145A32") : Color(hex: "#8A431F"))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background((findingCount == 0 ? Color(hex: "#D5F5E3") : Color(hex: "#F5E6DA")), in: Capsule())
        }
    }

    private func emailAnalysis() {
        guard let url = ContentFeedbackEmail.analysisURL(analysis) else {
            showsMailError = true
            return
        }
        openURL(url) { accepted in
            if !accepted { showsMailError = true }
        }
    }
}

private struct ContentQualityFindingRow: View {
    let finding: ContentQualityFinding

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: finding.severity.systemImage)
                .foregroundStyle(finding.severity.color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(finding.message)
                    .font(.callout)
                    .foregroundStyle(Color.hbTextPrimary)
                Text("\(finding.area.rawValue) · \(finding.contentID)")
                    .font(.caption)
                    .foregroundStyle(Color.hbTextMuted)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 3)
    }
}

private extension ContentQualitySeverity {
    var systemImage: String {
        switch self {
        case .note: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .note: return Color.hbAccent
        case .warning: return Color(hex: "#9B4A20")
        case .error: return Color(hex: "#B42318")
        }
    }
}

#Preview {
    NavigationStack {
        ContentQualityReviewView(analysis: ContentQualityAnalysis(
            questionCount: 1_014,
            flashcardCount: 640,
            handbookBlockCount: 1_200,
            findings: [
                ContentQualityFinding(area: .questions, contentID: "q-41", message: "Prompt is duplicated by another question", severity: .warning),
                ContentQualityFinding(area: .flashcards, contentID: "q-72", message: "Question was excluded from flashcards: multiple answers", severity: .warning)
            ]
        ))
    }
}
