import SwiftUI

struct RootTabView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("readingThemeStyle") private var readingThemeStyleRaw = ReadingThemeStyle.classic.rawValue
    @AppStorage("readingFontSizeAdjustment") private var readerFontSizeAdjustment = 0.0
    private let dependencies: AppDependencies
    @State private var isShowingSettings = false

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                TabView {
                    Tab("Home", systemImage: "square.grid.2x2") {
                        QuizRootView(
                            dependencies: dependencies.quiz,
                            handbookDependencies: dependencies.handbook,
                            searchDependencies: dependencies.search,
                            onOpenSettings: { isShowingSettings = true }
                        )
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
                        NavigationStack {
                            SearchView(dependencies: dependencies.search)
                        }
                    }
                }
                .tint(Color.hbAccent)
                .sheet(isPresented: $isShowingSettings) {
                    ReaderSettingsSheet(
                        themeStyle: Binding(
                            get: { ReadingThemeStyle(rawValue: readingThemeStyleRaw) ?? .classic },
                            set: { readingThemeStyleRaw = $0.rawValue }
                        ),
                        fontSizeAdjustment: Binding(
                            get: { CGFloat(readerFontSizeAdjustment) },
                            set: { readerFontSizeAdjustment = Double($0) }
                        )
                    )
                }
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
