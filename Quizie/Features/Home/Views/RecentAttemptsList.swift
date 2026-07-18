import SwiftUI

struct RecentAttemptsList: View {
    let attempts: [ExamAttemptSnapshot]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENT ATTEMPTS")
                .font(HBFont.sans(11, weight: .semibold))
                .kerning(1.5)
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
						.font(.system(size: 18, weight: .semibold))
						.foregroundColor(attempt.passed ? Color(hex: "#145A32") : Color(hex: "#922B21"))
				}

            // Attempt details
			HStack {
				VStack(alignment: .leading, spacing: 3) {
					Text(attempt.passed ? "Passed" : "Not Passed")
						.font(HBFont.sans(14, weight: .semibold))
						.foregroundColor(attempt.passed ? Color(hex: "#145A32") : Color(hex: "#922B21"))
						.frame(maxWidth: .infinity, alignment: .leading)

					HStack(spacing: 8) {
						Label(attempt.formattedElapsed, systemImage: "clock")
							.font(HBFont.sans(12))
							.foregroundColor(.hbTextMuted)

						Text("•")
							.foregroundColor(.hbTextMuted)

						Text(attempt.formattedAttemptedDate)
							.font(HBFont.sans(12))
							.foregroundColor(.hbTextMuted)
					}
				}

				HStack(alignment: .firstTextBaseline,spacing: 0.0) {
					Text("\(attempt.score)")
						.font(.system(size: 26, weight: .medium, design: .rounded))
					Text("/\(attempt.totalQuestions)")
						.font(.system(size: 16, design: .rounded))
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

// MARK: - Preview
#Preview("Quiz Lobby") {
    let services = PersistenceServices(attemptStore: InMemoryExamAttemptStore(), progressStore: InMemoryReadingProgressStore(), highlightStore: InMemoryHighlightStore())
    NavigationStack {
        QuizLobbyView(
            engine: QuizEngine(questionRepository: InMemoryQuestionRepository([])),
            attemptHistory: services.attempts
        )
    }
}

#Preview("Quiz Lobby with History") {
    let attempts = [
        ExamAttemptSnapshot(id: UUID(), attemptDate: Date().addingTimeInterval(-13*60*60*60), score: 20, totalQuestions: 24, passed: true, elapsedSeconds: 678000, didTimeOut: false, testID: nil),
        ExamAttemptSnapshot(id: UUID(), attemptDate: Date().addingTimeInterval(-172800), score: 19, totalQuestions: 24, passed: false, elapsedSeconds: 2100, didTimeOut: false, testID: nil),
        ExamAttemptSnapshot(id: UUID(), attemptDate: Date().addingTimeInterval(-259200), score: 22, totalQuestions: 24, passed: true, elapsedSeconds: 1650, didTimeOut: false, testID: nil),
    ]
    let services = PersistenceServices(attemptStore: InMemoryExamAttemptStore(attempts: attempts), progressStore: InMemoryReadingProgressStore(), highlightStore: InMemoryHighlightStore())
    
    NavigationStack {
        QuizLobbyView(
            engine: QuizEngine(questionRepository: InMemoryQuestionRepository([])),
            attemptHistory: services.attempts
        )
    }
}
