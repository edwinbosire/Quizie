import SwiftUI

struct TestsStatsCard: View {
    let attempts: [ExamAttemptSnapshot]

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
