import SwiftUI

struct QuizLobbyView: View {
    let engine: QuizEngine
    let attemptHistory: AttemptHistory
    var onOpenFlashcards: () -> Void = {}
    var onOpenMatchGame: () -> Void = {}
    private var attempts: [ExamAttemptSnapshot] { attemptHistory.attempts }

	var body: some View {
		content
			.background(Color.hbBackground.ignoresSafeArea())
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
                        .font(.caption2.weight(.semibold))
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
			Button(action: { engine.startExam() }) {
				HStack(spacing: 10) {
					Image(systemName: "play.fill")
						.font(.subheadline.weight(.semibold))
					Text(attempts.isEmpty ? "Start Practice Exam" : "Try Another Exam")
						.font(.headline.weight(.semibold))
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

// MARK: - Previews

#Preview("Quiz Lobby - First Visit") {
    let services = PersistenceServices(
        attemptStore: InMemoryExamAttemptStore(),
        progressStore: InMemoryReadingProgressStore(),
        highlightStore: InMemoryHighlightStore()
    )

    NavigationStack {
        QuizLobbyView(
            engine: QuizEngine(questionRepository: InMemoryQuestionRepository([])),
            attemptHistory: services.attempts
        )
    }
}

#Preview("Quiz Lobby - Returning Learner") {
    let attempts = [
        ExamAttemptSnapshot(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            attemptDate: Date().addingTimeInterval(-46_800),
            score: 20,
            totalQuestions: 24,
            passed: true,
            elapsedSeconds: 1_678,
            didTimeOut: false,
            testID: nil
        ),
        ExamAttemptSnapshot(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            attemptDate: Date().addingTimeInterval(-172_800),
            score: 16,
            totalQuestions: 24,
            passed: false,
            elapsedSeconds: 2_100,
            didTimeOut: false,
            testID: nil
        ),
        ExamAttemptSnapshot(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            attemptDate: Date().addingTimeInterval(-259_200),
            score: 22,
            totalQuestions: 24,
            passed: true,
            elapsedSeconds: 1_650,
            didTimeOut: false,
            testID: nil
        )
    ]
    let services = PersistenceServices(
        attemptStore: InMemoryExamAttemptStore(attempts: attempts),
        progressStore: InMemoryReadingProgressStore(),
        highlightStore: InMemoryHighlightStore()
    )

    NavigationStack {
        QuizLobbyView(
            engine: QuizEngine(questionRepository: InMemoryQuestionRepository([])),
            attemptHistory: services.attempts
        )
    }
}

// MARK: - Lobby Hero
