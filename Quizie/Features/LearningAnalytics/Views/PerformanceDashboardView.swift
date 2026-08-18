import SwiftUI

struct PerformanceConceptDestination: Hashable {
    let conceptID: String
}

struct PerformanceDashboardView: View {
    let service: PerformanceReportService
    let onAction: (RecommendedAction, ConceptPerformance) -> Void

    private var report: LearnerPerformanceReport { service.report }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                overview
                if report.concepts.allSatisfy({ $0.evidenceCount == 0 }) {
                    ContentUnavailableView("No performance history yet", systemImage: "chart.bar.xaxis", description: Text("Answer quiz questions or review flashcards to build your first insights."))
                        .frame(minHeight: 280)
                } else {
                    conceptSection("NEEDS ATTENTION", concepts: Array(report.weaknesses.prefix(5)), emptyMessage: "No confident weaknesses detected")
                    conceptSection("STRONG AREAS", concepts: Array(report.strengths.prefix(5)), emptyMessage: "Keep learning to identify strong areas")
                    recommendations
                }
            }
            .padding(20)
        }
        .background(Color.hbBackground)
        .navigationTitle("Performance")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: PerformanceConceptDestination.self) { destination in
            if let concept = report.concepts.first(where: { $0.id == destination.conceptID }) {
                ConceptPerformanceDetailView(concept: concept, report: report, onAction: onAction)
            }
        }
        .onAppear { service.refresh() }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                metric(title: "RECENT MOCK AVERAGE", value: report.examAnalytics.recentAverage.percentOrDash, detail: report.examAnalytics.recentScoreTrend.label, color: report.examAnalytics.recentScoreTrend.color)
                Divider().frame(height: 66)
                metric(title: "EXAM READINESS", value: report.readiness.label, detail: report.examAnalytics.completedExamCount == 0 ? "Complete a mock exam" : "Based on recent evidence", color: report.readiness.color)
            }
            if let mastery = report.overallMastery {
                ProgressView(value: mastery)
                    .tint(report.readiness.color)
                    .accessibilityLabel("Overall mastery")
                    .accessibilityValue(mastery.percent)
            }
        }
        .padding(20)
        .background(Color.hbSurface, in: RoundedRectangle(cornerRadius: HBRadius.md))
        .overlay { RoundedRectangle(cornerRadius: HBRadius.md).stroke(Color.hbBorder) }
    }

    private func metric(title: String, value: String, detail: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).appFont(.caption2.weight(.semibold)).foregroundStyle(Color.hbTextMuted)
            Text(value).appFont(.title2.weight(.bold)).foregroundStyle(color).minimumScaleFactor(0.75).lineLimit(1)
            Text(detail).appFont(.caption).foregroundStyle(Color.hbTextSecondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func conceptSection(_ title: String, concepts: [ConceptPerformance], emptyMessage: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).appFont(.caption.weight(.semibold)).foregroundStyle(Color.hbTextMuted)
            if concepts.isEmpty {
                Text(emptyMessage).appFont(.callout).foregroundStyle(Color.hbTextSecondary).padding(.vertical, 12)
            } else {
                ForEach(concepts) { concept in
                    NavigationLink(value: PerformanceConceptDestination(conceptID: concept.id)) {
                        HStack(spacing: 12) {
                            Circle().fill(concept.classification.color).frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(concept.displayName).appFont(.callout.weight(.semibold)).foregroundStyle(Color.hbTextPrimary)
                                Text("\(concept.evidenceCount) observations · \(concept.trend.label)").appFont(.caption).foregroundStyle(Color.hbTextMuted)
                            }
                            Spacer()
                            Text(concept.mastery.percentOrDash).appFont(.headline.weight(.semibold)).foregroundStyle(concept.classification.color).monospacedDigit()
                            Image(systemName: "chevron.right").appFont(.caption.weight(.bold)).foregroundStyle(Color.hbTextMuted)
                        }
                        .padding(15)
                        .background(Color.hbSurface, in: RoundedRectangle(cornerRadius: HBRadius.md))
                        .overlay { RoundedRectangle(cornerRadius: HBRadius.md).stroke(Color.hbBorder) }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var recommendations: some View {
        if !report.recommendations.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("RECOMMENDED NEXT").appFont(.caption.weight(.semibold)).foregroundStyle(Color.hbTextMuted)
                ForEach(report.recommendations.prefix(3)) { recommendation in
                    if let concept = report.concepts.first(where: { $0.id == recommendation.conceptID }) {
                        RecommendationCard(recommendation: recommendation, concept: concept, onAction: onAction)
                    }
                }
            }
        }
    }
}

struct ConceptPerformanceDetailView: View {
    let concept: ConceptPerformance
    let report: LearnerPerformanceReport
    let onAction: (RecommendedAction, ConceptPerformance) -> Void

    private var children: [ConceptPerformance] {
        report.concepts.filter { concept.childIDs.contains($0.id) && $0.mastery != nil }.sorted { ($0.mastery ?? 1) < ($1.mastery ?? 1) }
    }

    private var recommendation: RevisionRecommendation? {
        report.recommendations.first { $0.conceptID == concept.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 12) {
                    metric("Mastery", concept.mastery.percentOrDash, concept.classification.color)
                    metric("Confidence", concept.confidence.confidenceLabel, Color.hbAccent)
                    metric("Trend", concept.trend.label, concept.trend.color)
                }

                VStack(spacing: 0) {
                    sourceRow("Exam mastery", value: concept.examMastery)
                    Divider()
                    sourceRow("Flashcard mastery", value: concept.flashcardMastery)
                    Divider()
                    sourceRow("Unique questions", text: "\(concept.uniqueQuestionCount)")
                    Divider()
                    sourceRow("Flashcard reviews", text: "\(concept.flashcardReviewCount)")
                }
                .padding(.horizontal, 16)
                .background(Color.hbSurface, in: RoundedRectangle(cornerRadius: HBRadius.md))
                .overlay { RoundedRectangle(cornerRadius: HBRadius.md).stroke(Color.hbBorder) }

                if !children.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SUBTOPICS").appFont(.caption.weight(.semibold)).foregroundStyle(Color.hbTextMuted)
                        ForEach(children) { child in
                            NavigationLink(value: PerformanceConceptDestination(conceptID: child.id)) {
                                HStack {
                                    Text(child.displayName).foregroundStyle(Color.hbTextPrimary)
                                    Spacer()
                                    Text(child.mastery.percentOrDash).foregroundStyle(child.classification.color).monospacedDigit()
                                    Image(systemName: "chevron.right").foregroundStyle(Color.hbTextMuted)
                                }
                                .appFont(.callout.weight(.medium))
                                .padding(14)
                                .background(Color.hbSurface, in: RoundedRectangle(cornerRadius: HBRadius.sm))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let recommendation {
                    RecommendationCard(recommendation: recommendation, concept: concept, onAction: onAction)
                }
            }
            .padding(20)
        }
        .background(Color.hbBackground)
        .navigationTitle(concept.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func metric(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 5) {
            Text(value).appFont(.headline.weight(.bold)).foregroundStyle(color).minimumScaleFactor(0.7)
            Text(title).appFont(.caption2).foregroundStyle(Color.hbTextMuted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(Color.hbSurface, in: RoundedRectangle(cornerRadius: HBRadius.md))
    }

    private func sourceRow(_ title: String, value: Double?) -> some View { sourceRow(title, text: value.percentOrDash) }
    private func sourceRow(_ title: String, text: String) -> some View {
        HStack { Text(title).foregroundStyle(Color.hbTextSecondary); Spacer(); Text(text).fontWeight(.semibold).foregroundStyle(Color.hbTextPrimary).monospacedDigit() }
            .appFont(.callout).padding(.vertical, 14)
    }
}

private struct RecommendationCard: View {
    let recommendation: RevisionRecommendation
    let concept: ConceptPerformance
    let onAction: (RecommendedAction, ConceptPerformance) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(concept.displayName, systemImage: "sparkles").appFont(.headline.weight(.semibold)).foregroundStyle(Color.hbTextPrimary)
            Text(recommendation.reason.explanation).appFont(.callout).foregroundStyle(Color.hbTextSecondary)
            FlowLayout(spacing: 8) {
                ForEach(recommendation.actions, id: \.rawValue) { action in
                    Button(action.label) { onAction(action, concept) }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.hbAccent)
                        .accessibilityIdentifier("performance.recommendation.\(action.rawValue)")
                }
            }
        }
        .padding(18)
        .background(Color.hbAccentLight.opacity(0.55), in: RoundedRectangle(cornerRadius: HBRadius.md))
    }
}

private extension Optional where Wrapped == Double {
    var percentOrDash: String { map(\.percent) ?? "—" }
}

private extension Double {
    var percent: String { "\(Int((min(max(self, 0), 1) * 100).rounded()))%" }
    var confidenceLabel: String { self >= 0.75 ? "High" : self >= 0.45 ? "Medium" : "Low" }
}

private extension PerformanceTrend {
    var label: String { rawValue == "unknown" ? "Not enough data" : rawValue.capitalized }
    var color: Color { self == .improving ? Color(hex: "#16794A") : self == .declining ? Color(hex: "#B42318") : Color.hbTextSecondary }
}

private extension MasteryClassification {
    var color: Color {
        switch self {
        case .critical: Color(hex: "#B42318")
        case .weak: Color(hex: "#D65A31")
        case .developing: Color(hex: "#A66B00")
        case .strong, .mastered: Color(hex: "#16794A")
        case .insufficientEvidence: Color.hbTextMuted
        }
    }
}

private extension ExamReadiness {
    var label: String {
        switch self {
        case .notEnoughData: "Not enough data"
        case .needsSignificantRevision: "Needs revision"
        case .progressing: "Progressing"
        case .approachingReadiness: "Nearly ready"
        case .likelyReady: "Likely ready"
        case .consistentlyStrong: "Consistently strong"
        }
    }
    var color: Color { self == .likelyReady || self == .consistentlyStrong ? Color(hex: "#16794A") : self == .needsSignificantRevision ? Color(hex: "#B42318") : Color.hbAccent }
}

private extension RecommendationReason {
    var explanation: String {
        switch self {
        case .lowMastery: "Build understanding across questions and recall practice."
        case .decliningPerformance: "Recent answers are weaker than your earlier results."
        case .forgetting: "This was previously strong but needs a quick refresher."
        case .examFlashcardMismatch: "Your recall and question performance do not yet agree."
        case .insufficientCoverage: "Try a few different questions to improve confidence."
        }
    }
}

private extension RecommendedAction {
    var label: String {
        switch self {
        case .readHandbook: "Read"
        case .reviewFlashcards: "Flashcards"
        case .practiceQuestions: "Practice"
        case .takeMiniQuiz: "Mini quiz"
        }
    }
}
