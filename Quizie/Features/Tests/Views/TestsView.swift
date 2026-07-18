import SwiftUI

struct TestsView: View {
    let dependencies: TestsFeatureDependencies
    private var attempts: [ExamAttemptSnapshot] { dependencies.quiz.attempts.attempts }
    @State private var selectedTest: PracticeTest?

    var body: some View {
        content
            .background(Color.hbAccent)
            .ignoresSafeArea(edges: .top)
            .fullScreenCover(item: $selectedTest) { test in
                QuizRootView(
                    dependencies: dependencies.quiz,
                    initialTestID: test.id,
                    configuration: test.configuration
                )
            }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 0) {
//                TestsHero()

                TestsStatsCard(attempts: attempts)
                    .padding(.horizontal, 16)
                    .padding(.top, 60)

                TestsList(
                    tests: TestCatalog.tests,
                    attempts: attempts,
                    onSelect: { selectedTest = $0 }
                )
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .background(Color.hbBackground)
        }
    }
}

// MARK: - Hero
