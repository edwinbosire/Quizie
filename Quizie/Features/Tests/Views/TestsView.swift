import SwiftUI

struct TestsView: View {
    let dependencies: TestsFeatureDependencies
    let onReturnHome: () -> Void
    private var attempts: [ExamAttemptSnapshot] { dependencies.quiz.attempts.attempts }
    @State private var selectedTest: PracticeTest?

    init(
        dependencies: TestsFeatureDependencies,
        onReturnHome: @escaping () -> Void = {}
    ) {
        self.dependencies = dependencies
        self.onReturnHome = onReturnHome
    }

    var body: some View {
        content
            .background(Color.hbBackground.ignoresSafeArea())
            .fullScreenCover(item: $selectedTest) { test in
                QuizRootView(
                    dependencies: dependencies.quiz,
                    flashcardDependencies: dependencies.flashcards,
                    initialTestID: test.id,
                    configuration: configuration(for: test),
                    onReturnHome: {
                        selectedTest = nil
                        onReturnHome()
                    },
                    onQuitQuiz: { selectedTest = nil }
                )
            }
    }

    private func configuration(for test: PracticeTest) -> QuizConfiguration {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestSingleQuestion") {
            return .custom(questionCount: 1, timeLimitSeconds: 60, passMarkCount: 1)
        }
        #endif
        return test.configuration
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 0) {
//                TestsHero()

                if attempts.isEmpty {
                    TestsStartCard {
                        selectedTest = TestCatalog.tests.first
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                } else {
                    TestsStatsCard(attempts: attempts)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                }

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

// MARK: - Previews

#Preview("Tests - Not Started") {
    let dependencies = try! AppDependencies.preview()

    NavigationStack {
        TestsView(dependencies: dependencies.tests)
    }
}

#Preview("Tests - Progress") {
    let attempts = [
        ExamAttemptSnapshot(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            attemptDate: Date().addingTimeInterval(-3_600),
            score: 21,
            totalQuestions: 24,
            passed: true,
            elapsedSeconds: 1_500,
            didTimeOut: false,
            testID: "test-1"
        ),
        ExamAttemptSnapshot(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            attemptDate: Date().addingTimeInterval(-86_400),
            score: 14,
            totalQuestions: 24,
            passed: false,
            elapsedSeconds: 2_100,
            didTimeOut: false,
            testID: "test-3"
        )
    ]
    let questions = try! BundleQuestionRepository().questions(count: 24, seed: "preview")
    let chapters = try! BundleHandbookRepository().document().chapters
    let dependencies = try! AppDependencies.preview(
        questions: questions,
        chapters: chapters,
        attempts: attempts
    )

    NavigationStack {
        TestsView(dependencies: dependencies.tests)
    }
}

// MARK: - Hero
