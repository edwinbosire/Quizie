import SwiftUI

struct RecentAttemptsList: View {
    let attempts: [ExamAttemptSnapshot]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENT ATTEMPTS")
                .appFont(.caption2.weight(.semibold))
                .foregroundColor(.hbTextMuted)
                .padding(.horizontal, 2)
            
            VStack(spacing: 8) {
                ForEach(attempts) { attempt in
                    RecentAttemptRow(attempt: attempt)
                }
            }
        }
    }
}

struct RecentAttemptRow: View {
    let attempt: ExamAttemptSnapshot
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
			Circle()
				.fill(attempt.passed ? Color(hex: "#D5F5E3") : Color(hex: "#FADBD8"))
				.frame(width: 42, height: 42)
				.overlay {
					Image(systemName: attempt.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
						.appFont(.headline.weight(.semibold))
						.foregroundColor(attempt.passed ? Color(hex: "#145A32") : Color(hex: "#922B21"))
				}

            // Attempt details
			HStack {
				VStack(alignment: .leading, spacing: 3) {
					Text(attempt.passed ? "Passed" : "Not Passed")
						.appFont(.footnote.weight(.semibold))
						.foregroundColor(attempt.passed ? Color(hex: "#145A32") : Color(hex: "#922B21"))
						.frame(maxWidth: .infinity, alignment: .leading)

					HStack(spacing: 8) {
						Label(attempt.formattedElapsed, systemImage: "clock")
							.appFont(.caption)
							.foregroundColor(.hbTextMuted)

						Text("•")
							.foregroundColor(.hbTextMuted)

						Text(attempt.formattedAttemptedDate)
							.appFont(.caption)
							.foregroundColor(.hbTextMuted)
					}
				}

				HStack(alignment: .firstTextBaseline,spacing: 0.0) {
					Text("\(attempt.score)")
						.appFont(.system(.title2, design: .rounded, weight: .medium))
					Text("/\(attempt.totalQuestions)")
						.appFont(.system(.callout, design: .rounded))
						.foregroundColor(.hbTextSecondary)
				}
			}
        }
        .padding(12)
        .background(Color.hbSurface)
        .cornerRadius(HBRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: HBRadius.md)
                .stroke(attempt.passed ? Color(hex: "#A9DFBF") : Color(hex: "#F1948A"), lineWidth: 1)
        )
    }
}
