import SwiftUI

struct RootTabView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(ReadingThemeStyle.storageKey) private var readingThemeStyleRaw = ReadingThemeStyle.classic.rawValue
    @AppStorage(ReaderTextSize.storageKey) private var readerTextSizeRaw = ReaderTextSize.standard.rawValue
    private let dependencies: AppDependencies
    private let qualityAnalysis: ContentQualityAnalysis
    @State private var isShowingSettings = false
    @State private var selectedTab: MainTab
    @State private var flashcardPath: [FlashcardDeck]

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        let questions = (try? dependencies.quiz.questions.questions(count: Int.max, seed: "content-quality-analysis")) ?? []
        qualityAnalysis = ContentQualityAnalyzer.analyze(
            questions: questions,
            guideCards: dependencies.flashcards.catalog.guideCards,
            flashcardAudit: dependencies.flashcards.catalog.guideCardAudit,
            chapters: dependencies.handbook.catalog.chapters
        )
        let arguments = ProcessInfo.processInfo.arguments
        let requestedTab: MainTab? = arguments.firstIndex(of: "-initialMainTab").flatMap { index in
            guard arguments.indices.contains(index + 1) else { return nil }
            return MainTab(rawValue: arguments[index + 1])
        }
        _selectedTab = State(initialValue: requestedTab ?? .home)
        let requestedDeck: FlashcardDeck? = arguments.firstIndex(of: "-initialFlashcardDeck").flatMap { index in
            guard arguments.indices.contains(index + 1) else { return nil }
            switch arguments[index + 1] {
            case "new": return .newCards
            case "due": return .due
            case "dates": return .dates
            default: return nil
            }
        }
        _flashcardPath = State(initialValue: requestedDeck.map { [$0] } ?? [])
        self._readerTextSizeRaw = AppStorage(
            wrappedValue: ReaderTextSize.loadAndMigrate().rawValue,
            ReaderTextSize.storageKey
        )
    }

    private var appAppearance: AppAppearance {
        AppAppearance(
            style: ReadingThemeStyle(rawValue: readingThemeStyleRaw) ?? .classic,
            textSize: ReaderTextSize(rawValue: readerTextSizeRaw) ?? .standard
        )
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                TabView(selection: $selectedTab) {
                    Tab("Home", systemImage: "square.grid.2x2", value: .home) {
                        QuizRootView(
                            dependencies: dependencies.quiz,
                            flashcardDependencies: dependencies.flashcards,
                            handbookDependencies: dependencies.handbook.reader,
                            showsMainNavigationBar: true,
                            onOpenSearch: { selectedTab = .search },
                            onOpenHandbook: { selectedTab = .handbook },
                            onOpenSettings: { isShowingSettings = true }
                        )
                    }

                    Tab("Tests", systemImage: "sparkle.text.clipboard", value: .tests) {
                        NavigationStack {
                            TestsView(
                                dependencies: dependencies.tests,
                                onReturnHome: { selectedTab = .home }
                            )
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
                        NavigationStack(path: $flashcardPath) {
                            FlashcardsView(dependencies: dependencies.flashcards)
                                .mainNavigationBar(
                                    title: "Flashcards",
                                    tab: .flashcards,
                                    onOpenSearch: { selectedTab = .search },
                                    onOpenHandbook: { selectedTab = .handbook },
                                    onOpenSettings: { isShowingSettings = true }
                                )
                                .flashcardNavigationDestinations(dependencies: dependencies.flashcards)
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
                        textSize: Binding(
                            get: { ReaderTextSize(rawValue: readerTextSizeRaw) ?? .standard },
                            set: { readerTextSizeRaw = $0.rawValue }
                        ),
                        qualityAnalysis: qualityAnalysis
                    )
                }
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
        .environment(\.appAppearance, appAppearance)
        .background(appAppearance.style.background.ignoresSafeArea())
        .preferredColorScheme(appAppearance.style == .night ? .dark : .light)
        .accessibilityIdentifier("app.root")
        .accessibilityValue("\(appAppearance.style.rawValue)-\(appAppearance.textSize.rawValue)")
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
