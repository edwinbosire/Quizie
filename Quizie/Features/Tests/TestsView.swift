import SwiftUI
import SwiftData

struct TestsView: View {
    @Query(sort: \ExamAttempt.attemptDate, order: .reverse) private var attempts: [ExamAttempt]
    @State private var selectedTest: PracticeTest?

    var body: some View {
        content
            .background(Color.hbAccent)
            .ignoresSafeArea(edges: .top)
            .fullScreenCover(item: $selectedTest) { test in
                QuizRootView(
                    initialTestID: test.id,
                    configuration: test.configuration
                )
            }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 0) {
//                TestsHero()

                TestsStatsCard(attempts: attempts)
                    .padding(.horizontal, 16)
                    .padding(.top, 60)

                TestsList(
                    tests: TestCatalog.tests,
                    attempts: attempts,
                    onSelect: { selectedTest = $0 }
                )
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .background(Color.hbBackground)
        }
    }
}

// MARK: - Hero
private struct TestsHero: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.hbAccent

            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 200, height: 200)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 50, y: -50)

            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 140, height: 140)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: -30, y: 140)

            VStack(alignment: .leading, spacing: 16) {
                Text("MOCK TESTS")
                    .font(HBFont.sans(11, weight: .semibold))
                    .kerning(2)
                    .foregroundColor(Color.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Choose Your\nPractice Test")
                    .font(HBFont.lora(30))
                    .foregroundColor(.white)
                    .lineSpacing(4)

                Text("Take any of the official-style practice tests below to gauge how ready you are.")
                    .font(HBFont.sans(15))
                    .foregroundColor(Color.white.opacity(0.7))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 60)
            .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Stats Card
private struct TestsStatsCard: View {
    let attempts: [ExamAttempt]

    var hasAttempts: Bool { !attempts.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("YOUR STATISTICS")
                        .font(HBFont.sans(11, weight: .semibold))
                        .kerning(1.5)
                        .foregroundColor(.hbTextMuted)

                    Text(hasAttempts ? "Across all attempts so far" : "Take your first test to get started")
                        .font(HBFont.sans(14))
                        .foregroundColor(.hbTextSecondary)
                }
                Spacer()

                VStack(spacing: 2) {
                    Text("\(attempts.count)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Color.hbAccent)
                    Text("ATTEMPTS")
                        .font(HBFont.sans(9, weight: .semibold))
                        .kerning(0.8)
                        .foregroundColor(.hbTextMuted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.hbAccentLight)
                .cornerRadius(HBRadius.sm)
            }

            HStack(spacing: 10) {
                PerformanceStat(
                    icon: "target",
                    value: hasAttempts ? String(format: "%.0f%%", attempts.averagePercentage) : "—",
                    label: "Avg Score",
                    color: Color.hbAccent
                )

                PerformanceStat(
                    icon: "trophy.fill",
                    value: hasAttempts ? "\(attempts.bestScore)/\(attempts.first?.totalQuestions ?? 24)" : "—",
                    label: "Best Score",
                    color: Color(hex: "#145A32")
                )

                PerformanceStat(
                    icon: "checkmark.circle.fill",
                    value: hasAttempts ? String(format: "%.0f%%", attempts.passRate) : "—",
                    label: "Pass Rate",
                    color: Color(hex: "#6E2C00")
                )
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color.hbAccent.opacity(0.08),
                    Color.hbAccent.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(HBRadius.md)
        .overlay(RoundedRectangle(cornerRadius: HBRadius.md).stroke(Color.hbAccent.opacity(0.15), lineWidth: 1))
    }
}

// MARK: - Tests List
private struct TestsList: View {
    let tests: [PracticeTest]
    let attempts: [ExamAttempt]
    let onSelect: (PracticeTest) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ALL TESTS")
                .font(HBFont.sans(11, weight: .semibold))
                .kerning(1.5)
                .foregroundColor(.hbTextMuted)
                .padding(.horizontal, 2)

            VStack(spacing: 8) {
                ForEach(tests) { test in
                    Button {
                        onSelect(test)
                    } label: {
                        TestRow(test: test, stats: attempts.stats(for: test.id))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Test Row
private struct TestRow: View {
    let test: PracticeTest
    let stats: PracticeTestStats?

    private var isAttempted: Bool { stats != nil }
    private var passed: Bool { stats?.passed ?? false }

    private var statusBg: Color {
        guard let stats else { return Color.hbAccentLight }
        return stats.passed ? Color(hex: "#D5F5E3") : Color(hex: "#FADBD8")
    }

    private var statusFg: Color {
        guard let stats else { return Color.hbAccent }
        return stats.passed ? Color(hex: "#145A32") : Color(hex: "#922B21")
    }

    private var borderColor: Color {
        guard let stats else { return Color.hbBorder }
        return stats.passed ? Color(hex: "#A9DFBF") : Color(hex: "#F1948A")
    }

    var body: some View {
        HStack(spacing: 12) {
            // Number / status indicator
            Circle()
                .fill(statusBg)
                .frame(width: 42, height: 42)
                .overlay {
                    if let stats {
                        Image(systemName: stats.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(statusFg)
                    } else {
                        Text("\(test.number)")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(statusFg)
                    }
                }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(test.title)
                        .font(HBFont.sans(15, weight: .semibold))
                        .foregroundColor(.hbTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 6) {
                        if let stats {
                            Text(stats.passed ? "Passed" : "Not Passed")
                                .font(HBFont.sans(12, weight: .semibold))
                                .foregroundColor(statusFg)

                            Text("•")
                                .foregroundColor(.hbTextMuted)

                            Text("\(stats.attempts) attempt\(stats.attempts == 1 ? "" : "s")")
                                .font(HBFont.sans(12))
                                .foregroundColor(.hbTextMuted)
                        } else {
                            Text(test.subtitle)
                                .font(HBFont.sans(12))
                                .foregroundColor(.hbTextMuted)
                        }
                    }
                }

                if let stats {
                    HStack(alignment: .firstTextBaseline, spacing: 0.0) {
                        Text("\(stats.bestScore)")
                            .font(.system(size: 24, weight: .medium, design: .rounded))
                            .foregroundColor(.hbTextPrimary)
                        Text("/\(stats.totalQuestions)")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundColor(.hbTextSecondary)
                    }
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.hbTextMuted.opacity(0.6))
                }
            }
        }
        .padding(12)
        .background(Color.hbSurface)
        .cornerRadius(HBRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: HBRadius.md)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

// MARK: - Previews
#Preview("Tests - empty") {
    TestsView()
        .modelContainer(for: [ExamAttempt.self, ReadingProgress.self, Highlight.self], inMemory: true)
}

#Preview("Tests - with attempts") {
    let container = try! ModelContainer(
        for: ExamAttempt.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext
    let samples: [ExamAttempt] = [
        ExamAttempt(attemptDate: Date().addingTimeInterval(-3600), score: 21, totalQuestions: 24, passed: true, elapsedSeconds: 1500, testID: "test-1"),
        ExamAttempt(attemptDate: Date().addingTimeInterval(-86400), score: 14, totalQuestions: 24, passed: false, elapsedSeconds: 2100, testID: "test-3"),
        ExamAttempt(attemptDate: Date().addingTimeInterval(-172800), score: 19, totalQuestions: 24, passed: true, elapsedSeconds: 1800, testID: "test-5"),
    ]
    samples.forEach { context.insert($0) }

    return TestsView()
        .modelContainer(container)
}
