import SwiftUI

struct QuizLobbyView: View {
    @EnvironmentObject var engine: QuizEngine
    @Environment(AttemptHistory.self) private var attemptHistory
    private var attempts: [ExamAttemptSnapshot] { attemptHistory.attempts }

	var body: some View {
		content
			.background(Color.hbAccent)
			.ignoresSafeArea(edges: .top)
	}

	private var content: some View {
		ScrollView {
			VStack(spacing: 0) {
				// Hero
				HeroHeader()

				// Performance Summary (only show if there are attempts)
				if !attempts.isEmpty {
					PerformanceSummary(attempts: attempts)
						.padding(.horizontal, 16)
						.padding(.top, 24)
				}

				// Info cards (only show for first-time users)
				if attempts.isEmpty {
					ExamInfoBar()
						.padding(.horizontal, 16)
						.padding(.top, 24)
						.transition(.asymmetric(
							insertion: .opacity.combined(with: .scale(scale: 0.95)),
							removal: .opacity.combined(with: .scale(scale: 0.95))
						))
				}

				// Recent Attempts (show last 3 if available)
				if !attempts.isEmpty {
					RecentAttemptsList(attempts: Array(attempts.prefix(3)))
						.padding(.horizontal, 16)
						.padding(.top, 20)
				}

				// Rules card
				RulesCard()
					.padding(.horizontal, 16)
					.padding(.top, 20)
			}
			.padding(.bottom, 20) // Space for fixed button
			.background(Color.hbBackground)
		}
		.safeAreaInset(edge: .bottom, spacing: 0.0) {
			// Fixed Start button at bottom
			startExamButton
		}
	}

	private var startExamButton: some View {
		VStack(spacing: 0) {
			Divider()

			Button {
				engine.startExam()
			} label: {
				HStack(spacing: 10) {
					Image(systemName: "play.fill")
						.font(.system(size: 15, weight: .semibold))
					Text(attempts.isEmpty ? "Start Practice Exam" : "Try Another Exam")
						.font(HBFont.sans(17, weight: .semibold))
				}
				.foregroundColor(.white)
				.frame(maxWidth: .infinity)
				.padding(.vertical, 16)
				.background(Color.hbAccent)
				.cornerRadius(HBRadius.md)
				.shadow(color: Color.hbAccent.opacity(0.35), radius: 8, x: 0, y: 4)
			}
			.padding(.horizontal, 16)
			.padding(.top, 12)
			.padding(.bottom, 16)
		}
		.background(Color.hbBackground)
	}
}

// MARK: - Lobby Hero
