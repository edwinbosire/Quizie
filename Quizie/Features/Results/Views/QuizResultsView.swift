import SwiftUI

struct QuizResultsView: View {
    let engine: QuizEngine
    var onReturnHome: (() -> Void)?
    @State private var showReview = false
    @State private var showConfetti = false

    var session: ExamSession? { engine.session }

    var body: some View {
        ZStack {
			ScrollViewReader { proxy in
				ScrollView {
					VStack(spacing: 0) {
						if let session {
							// Hero result banner
							ResultHero(session: session, showConfetti: $showConfetti)

							// Score breakdown cards
							ScoreBreakdown(session: session)
								.padding(.horizontal, 16)
								.padding(.top, 24)

							// Action buttons
							ActionButtons(
								engine: engine,
								showReview: $showReview,
								onReturnHome: onReturnHome ?? engine.returnToLobby
							)
								.padding(.horizontal, 16)
								.padding(.top, 20)

							// Answer review list
							if showReview {
								AnswerReviewList(session: session)
									.padding(.top, 24)
									.transition(.move(edge: .bottom).combined(with: .opacity))
									.id(3)
							}
						}
					}
					.padding(.bottom, 48)
				}
				.background(Color.hbBackground)
				.ignoresSafeArea(edges: .top)
				.onChange(of: showReview) { _, newValue in
					if newValue {
						withAnimation(.easeIn.delay(1)) {
							proxy.scrollTo(3, anchor: .top)
						}
					}
				}
			}
            // Confetti overlay
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Previews

#Preview("Quiz Results - Passed") {
    NavigationStack {
        QuizResultsView(engine: PreviewResultsEngine.passedEngine)
    }
}

#Preview("Quiz Results - Failed") {
    NavigationStack {
        QuizResultsView(engine: PreviewResultsEngine.failedEngine)
    }
}

// MARK: - Result Hero
