import SwiftUI

struct TestsStatsCard: View {
    let attempts: [ExamAttemptSnapshot]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("YOUR STATISTICS")
                        .appFont(.caption2.weight(.semibold))
                        .foregroundColor(.hbTextMuted)

                    Text("Across all attempts so far")
                        .appFont(.footnote)
                        .foregroundColor(.hbTextSecondary)
                }
                Spacer()

                VStack(spacing: 2) {
                    Text("\(attempts.count)")
                        .appFont(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundColor(Color.hbAccent)
                    Text("ATTEMPTS")
                        .appFont(.caption2.weight(.semibold))
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
                    value: String(format: "%.0f%%", attempts.averagePercentage),
                    label: "Avg Score",
                    color: Color.hbAccent
                )

                PerformanceStat(
                    icon: "trophy.fill",
                    value: "\(attempts.bestScore)/\(attempts.first?.totalQuestions ?? 24)",
                    label: "Best Score",
                    color: Color(hex: "#145A32")
                )

                PerformanceStat(
                    icon: "checkmark.circle.fill",
                    value: String(format: "%.0f%%", attempts.passRate),
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

struct TestsStartCard: View {
    let onStart: () -> Void

    var body: some View {
        Button(action: onStart) {
            HStack(spacing: 14) {
                Image(systemName: "play.fill")
                    .appFont(.headline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.16))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Start your first test")
                        .appFont(.headline.weight(.semibold))
                        .foregroundColor(.white)

                    Text("Answer 24 questions and see how ready you are.")
                        .appFont(.footnote)
                        .foregroundColor(.white.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.right")
                    .appFont(.footnote.weight(.semibold))
                    .foregroundColor(.white)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.hbAccent)
            .clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tests.startFirst")
    }
}

// MARK: - Tests List
