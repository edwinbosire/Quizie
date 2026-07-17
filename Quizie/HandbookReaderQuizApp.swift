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
    private let dependencies: AppDependencies

    init() {
        do {
            dependencies = try .production()
        } catch {
            fatalError("Unable to initialize persistence: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(dependencies: dependencies)
        }
        .modelContainer(dependencies.modelContainer)
    }
}

struct RootTabView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                TabView {
                    Tab("Home", systemImage: "square.grid.2x2") {
                        QuizRootView(dependencies: dependencies.quiz)
                    }

                    Tab("Tests", systemImage: "sparkle.text.clipboard") {
                        TestsView(dependencies: dependencies.tests)
                    }

                    Tab("Handbook", systemImage: "checklist") {
                        NavigationStack {
                            HandbookView(dependencies: dependencies.handbook)
                        }
                    }

                    Tab("Search", systemImage: "magnifyingglass", role: .search) {
                        SearchView(dependencies: dependencies.search)
                    }
                }
                .tint(Color.hbAccent)
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
        .alert(item: Binding(
            get: { dependencies.persistenceIssues.issue },
            set: { if $0 == nil { dependencies.persistenceIssues.dismiss() } }
        )) { issue in
            Alert(title: Text("Unable to Save Data"), message: Text(issue.message), dismissButton: .default(Text("OK"), action: dependencies.persistenceIssues.dismiss))
        }
    }
}
