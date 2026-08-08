import SwiftUI

struct RootTabView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("readingThemeStyle") private var readingThemeStyleRaw = ReadingThemeStyle.classic.rawValue
    @AppStorage("readingFontSizeAdjustment") private var readerFontSizeAdjustment = 0.0
    private let dependencies: AppDependencies
    @State private var isShowingSettings = false
    @State private var selectedTab: MainTab = .home

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                TabView(selection: $selectedTab) {
                    Tab("Home", systemImage: "square.grid.2x2", value: .home) {
                        QuizRootView(
                            dependencies: dependencies.quiz,
                            showsMainNavigationBar: true,
                            onOpenSearch: { selectedTab = .search },
                            onOpenHandbook: { selectedTab = .handbook },
                            onOpenSettings: { isShowingSettings = true }
                        )
                    }

                    Tab("Tests", systemImage: "sparkle.text.clipboard", value: .tests) {
                        NavigationStack {
                            TestsView(dependencies: dependencies.tests)
                                .mainNavigationBar(
                                    title: "Tests",
                                    tab: .tests,
                                    onOpenSearch: { selectedTab = .search },
                                    onOpenHandbook: { selectedTab = .handbook },
                                    onOpenSettings: { isShowingSettings = true }
                                )
                        }
                    }

                    Tab("Flashcards", systemImage: "rectangle.stack.fill", value: .flashcards) {
                        NavigationStack {
                            FlashcardsView(dependencies: dependencies.quiz)
                                .mainNavigationBar(
                                    title: "Flashcards",
                                    tab: .flashcards,
                                    onOpenSearch: { selectedTab = .search },
                                    onOpenHandbook: { selectedTab = .handbook },
                                    onOpenSettings: { isShowingSettings = true }
                                )
                        }
                    }

                    Tab("Handbook", systemImage: "checklist", value: .handbook) {
                        NavigationStack {
                            HandbookView(dependencies: dependencies.handbook)
                                .mainNavigationBar(
                                    title: "Handbook",
                                    tab: .handbook,
                                    onOpenSearch: { selectedTab = .search },
                                    onOpenHandbook: { selectedTab = .handbook },
                                    onOpenSettings: { isShowingSettings = true }
                                )
                        }
                    }

                    Tab("Search", systemImage: "magnifyingglass", value: .search, role: .search) {
                        NavigationStack {
                            SearchView(dependencies: dependencies.search)
                                .mainNavigationBar(
                                    title: "Search",
                                    tab: .search,
                                    onOpenSearch: { selectedTab = .search },
                                    onOpenHandbook: { selectedTab = .handbook },
                                    onOpenSettings: { isShowingSettings = true }
                                )
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

#Preview("Main Tabs") {
    let defaults = UserDefaults(suiteName: "RootTabViewPreview")!
    defaults.set(true, forKey: "hasCompletedOnboarding")

    return RootTabView(dependencies: try! AppDependencies.preview())
        .defaultAppStorage(defaults)
}
