import SwiftUI

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
                        .environment(dependencies.handbook.catalog)
                        .environment(dependencies.handbook.progress)
                        .environment(dependencies.handbook.highlights)
                    }

                    Tab("Search", systemImage: "magnifyingglass", role: .search) {
                        SearchView(dependencies: dependencies.search)
                            .environment(dependencies.search.catalog)
                            .environment(dependencies.search.progress)
                            .environment(dependencies.search.highlights)
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
            Alert(
                title: Text("Unable to Save Data"),
                message: Text(issue.message),
                dismissButton: .default(Text("OK"), action: dependencies.persistenceIssues.dismiss)
            )
        }
    }
}
