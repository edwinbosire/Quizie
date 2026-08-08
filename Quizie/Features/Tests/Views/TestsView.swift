import SwiftUI

struct TestsView: View {
    let dependencies: TestsFeatureDependencies
    private var attempts: [ExamAttemptSnapshot] { dependencies.quiz.attempts.attempts }
    @State private var selectedTest: PracticeTest?

    var body: some View {
        content
            .background(Color.hbBackground.ignoresSafeArea())
            .fullScreenCover(item: $selectedTest) { test in
                QuizRootView(
                    dependencies: dependencies.quiz,
                    initialTestID: test.id,
                    configuration: test.configuration,
                    onQuitQuiz: { selectedTest = nil }
                )
            }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 0) {
//                TestsHero()

                TestsStatsCard(attempts: attempts)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                TestsList(
                    tests: TestCatalog.tests,
                    attempts: attempts,
                    onSelect: { selectedTest = $0 }
                )
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .background(Color.hbBackground)
        }
        .contentMargins(.top, 16, for: .scrollContent)
    }
}

// MARK: - Hero
