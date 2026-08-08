import SwiftUI

struct QuizLobbyView: View {
    let engine: QuizEngine
    let attemptHistory: AttemptHistory
    var onOpenFlashcards: () -> Void = {}
    var onOpenMatchGame: () -> Void = {}
    private var attempts: [ExamAttemptSnapshot] { attemptHistory.attempts }

	var body: some View {
		content
//			.background(Color.hbAccent)
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
					ExamInfoBar(engine: engine)
						.padding(.horizontal, 16)
						.padding(.top, 24)
						.transition(.asymmetric(
							insertion: .opacity.combined(with: .scale(scale: 0.95)),
							removal: .opacity.combined(with: .scale(scale: 0.95))
						))
				}

				startExamCard
					.padding(.horizontal, 16)
					.padding(.top, 20)

                VStack(alignment: .leading, spacing: 10) {
                    Text("QUICK STUDY")
                        .font(HBFont.sans(11, weight: .semibold))
                        .kerning(1.5)
                        .foregroundStyle(Color.hbTextMuted)

                    HStack(alignment: .top, spacing: 12) {
                        FlashcardHomeCard(onOpen: onOpenFlashcards)
                        MatchGameHomeCard(onOpen: onOpenMatchGame)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)

				// Recent Attempts (show last 3 if available)
				if !attempts.isEmpty {
					RecentAttemptsList(attempts: Array(attempts.prefix(3)))
						.padding(.horizontal, 16)
						.padding(.top, 20)
				}

				// Rules card
				RulesCard(engine: engine)
					.padding(.horizontal, 16)
					.padding(.top, 20)
			}
			.padding(.bottom, 20)
			.background(Color.hbBackground)
		}
	}

	private var startExamCard: some View {
		VStack(spacing: 0) {
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
			.accessibilityIdentifier("quiz.start")
		}
		.padding(12)
		.background(Color.hbSurface)
		.clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
		.overlay {
			RoundedRectangle(cornerRadius: HBRadius.md)
				.stroke(Color.hbBorder, lineWidth: 1)
		}
	}
}

// MARK: - Lobby Hero
