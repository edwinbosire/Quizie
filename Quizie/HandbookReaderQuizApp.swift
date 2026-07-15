//
//  HandbookReaderQuizApp.swift
//  HandbookReaderQuiz
//
//  Created by Edwin Bosire on 28/03/2026.
//

import SwiftUI
import SwiftData

@main
struct HandbookReaderQuizApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView(dependencies: .live())
        }
        .modelContainer(for: [ExamAttempt.self, ReadingProgress.self, Highlight.self])
    }
}

struct RootTabView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    private let dependencies: AppDependencies
    @State private var handbookCatalog: HandbookCatalog

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _handbookCatalog = State(initialValue: HandbookCatalog(repository: dependencies.handbook))
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                TabView {
                    Tab("Home", systemImage: "square.grid.2x2") {
                        QuizRootView(questionRepository: dependencies.questions)
                    }

                    Tab("Tests", systemImage: "sparkle.text.clipboard") {
                        TestsView(questionRepository: dependencies.questions)
                    }

                    Tab("Handbook", systemImage: "checklist") {
                        NavigationStack {
                            HandbookView()
                        }
                    }

                    Tab("Search", systemImage: "magnifyingglass", role: .search) {
                        SearchView()
                    }
                }
                .tint(Color.hbAccent)
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
        .environment(handbookCatalog)
    }
}
