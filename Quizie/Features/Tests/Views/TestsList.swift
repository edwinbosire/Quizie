import SwiftUI

struct TestsList: View {
    let tests: [PracticeTest]
    let attempts: [ExamAttemptSnapshot]
    let onSelect: (PracticeTest) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ALL TESTS")
                .font(.caption2.weight(.semibold))
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
                            .font(.headline.weight(.semibold))
                            .foregroundColor(statusFg)
                    } else {
                        Text("\(test.number)")
                            .font(.system(.callout, design: .rounded, weight: .semibold))
                            .foregroundColor(statusFg)
                    }
                }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(test.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.hbTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 6) {
                        if let stats {
                            Text(stats.passed ? "Passed" : "Not Passed")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(statusFg)

                            Text("•")
                                .foregroundColor(.hbTextMuted)

                            Text("\(stats.attempts) attempt\(stats.attempts == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.hbTextMuted)
                        } else {
                            Text(test.subtitle)
                                .font(.caption)
                                .foregroundColor(.hbTextMuted)
                        }
                    }
                }

                if let stats {
                    HStack(alignment: .firstTextBaseline, spacing: 0.0) {
                        Text("\(stats.bestScore)")
                            .font(.system(.title2, design: .rounded, weight: .medium))
                            .foregroundColor(.hbTextPrimary)
                        Text("/\(stats.totalQuestions)")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.hbTextSecondary)
                    }
                } else {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.medium))
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
