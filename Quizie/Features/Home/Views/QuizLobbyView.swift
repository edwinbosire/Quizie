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

				quickStartModes
					.padding(.horizontal, 16)
					.padding(.top, 20)

                VStack(alignment: .leading, spacing: 10) {
                    Text("QUICK STUDY")
                        .appFont(.caption2.weight(.semibold))
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

	private var quickStartModes: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QUICK START")
                .appFont(.caption2.weight(.semibold))
                .foregroundStyle(Color.hbTextMuted)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                QuizModePill(title: "Exam Mode", subtitle: engine.configuration.summaryLabel, icon: "checklist.checked", colors: [Color(hex: "#2855A6"), Color(hex: "#419EE8")]) {
                    engine.startExam()
                }
                .accessibilityIdentifier("quiz.start")

                QuizModePill(title: "Streak", subtitle: engine.bestStreak == 0 ? "All questions" : "Best: \(engine.bestStreak)", icon: "flame.fill", colors: [Color(hex: "#F06449"), Color(hex: "#F5A623")]) {
                    engine.startStreak()
                }
                .accessibilityIdentifier("quiz.streak.start")
            }
        }
	}
}

private struct QuizModePill: View {
    let title: String
    let subtitle: String
    let icon: String
    let colors: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .appFont(.title3.weight(.semibold))
                    .frame(width: 46, height: 46)
                    .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .appFont(.headline.weight(.semibold))
                    Text(subtitle)
                        .appFont(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .opacity(0.78)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 92)
            .background(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: HBRadius.pill))
            .shadow(color: colors[0].opacity(0.22), radius: 9, x: 0, y: 5)
            .contentShape(RoundedRectangle(cornerRadius: HBRadius.pill))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(subtitle)")
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
