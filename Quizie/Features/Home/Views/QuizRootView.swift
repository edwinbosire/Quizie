import SwiftUI

/// Root view that coordinates all quiz phases via QuizEngine
struct QuizRootView: View {
    let initialTestID: String?
    private let dependencies: QuizFeatureDependencies
    private let flashcardDependencies: FlashcardFeatureDependencies
    private let handbookDependencies: HandbookReaderDependencies?
    private let showsMainNavigationBar: Bool
    private let onOpenSearch: () -> Void
    private let onOpenHandbook: () -> Void
    private let onOpenSettings: () -> Void
    private let onReturnHome: (() -> Void)?
    private let onQuitQuiz: (() -> Void)?
    @State private var engine: QuizEngine
    @State private var navigationPath = NavigationPath()

    init(
        dependencies: QuizFeatureDependencies,
        flashcardDependencies: FlashcardFeatureDependencies,
        handbookDependencies: HandbookReaderDependencies? = nil,
        initialTestID: String? = nil,
        configuration: QuizConfiguration = .practice,
        showsMainNavigationBar: Bool = false,
        onOpenSearch: @escaping () -> Void = {},
        onOpenHandbook: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {},
        onReturnHome: (() -> Void)? = nil,
        onQuitQuiz: (() -> Void)? = nil
    ) {
        self.dependencies = dependencies
        self.flashcardDependencies = flashcardDependencies
        self.handbookDependencies = handbookDependencies
        self.initialTestID = initialTestID
        self.showsMainNavigationBar = showsMainNavigationBar
        self.onOpenSearch = onOpenSearch
        self.onOpenHandbook = onOpenHandbook
        self.onOpenSettings = onOpenSettings
        self.onReturnHome = onReturnHome
        self.onQuitQuiz = onQuitQuiz
        _engine = State(initialValue: QuizEngine(
            configuration: configuration,
            questionRepository: dependencies.questions,
            attemptStore: dependencies.attempts,
            learningEvents: dependencies.learningEvents,
            clock: dependencies.clock,
            scheduler: dependencies.scheduler
        ))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                switch engine.phase {
                case .lobby:
                    QuizLobbyView(
                        engine: engine,
                        attemptHistory: dependencies.attempts,
                        performance: dependencies.performance,
                        onOpenFlashcards: openFlashcards,
                        onOpenMatchGame: openMatchGame,
                        onOpenBookmarks: openBookmarks,
                        highlightCount: handbookDependencies?.highlights.highlights.count ?? 0,
                        onOpenHighlights: openHighlights,
                        onOpenPerformance: openPerformance
                    )
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal: .move(edge: .leading)
                        ))

                case .question(let idx):
                    QuizQuestionView(engine: engine, questionIndex: idx, questionSourceResolver: dependencies.questionSources, onQuit: quitQuiz)
                        .id(idx)   // force view refresh on index change
                        .navigationBarBackButtonHidden(true)
                        .ignoresSafeArea(.container, edges: .bottom)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))

                case .results:
                    QuizResultsView(engine: engine, onReturnHome: returnHome)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing)
                        ))

                case .streakResult:
                    StreakResultView(engine: engine, onReturnHome: returnHome)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing)
                        ))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: engine.phase.id)
            .mainNavigationBar(
                title: "Life in the UK",
                tab: .home,
                isVisible: showsMainNavigationBar && engine.phase == .lobby,
                onOpenSearch: onOpenSearch,
                onOpenHandbook: onOpenHandbook,
                onOpenSettings: onOpenSettings
            )
            .navigationDestination(for: HomeNavigationDestination.self) { destination in
                switch destination {
                case .flashcards:
                    FlashcardsView(dependencies: flashcardDependencies)
                case .matchGame:
                    MatchGameView()
                case .bookmarks:
                    BookmarkedQuestionsView(questionRepository: dependencies.questions, questionSourceResolver: dependencies.questionSources)
                case .highlights:
                    if let handbookDependencies {
                        HighlightsView(dependencies: handbookDependencies)
                    }
                case .performance:
                    PerformanceDashboardView(service: dependencies.performance, onAction: performRecommendation)
                case .handbookConcept(let conceptID):
                    handbookDestination(conceptID: conceptID)
                }
            }
            .flashcardNavigationDestinations(dependencies: flashcardDependencies)
        }
        .toolbar(shouldShowTabBar ? .visible : .hidden, for: .tabBar)
        .toolbar(isShowingQuestion ? .hidden : .visible, for: .navigationBar)
        .alert("Time's Up!", isPresented: Binding(
            get: { engine.didTimeOut },
            set: { if !$0 { engine.acknowledgeTimeout() } }
        )) {
            Button("See Results") { engine.acknowledgeTimeout() }
        } message: {
            Text("You've run out of time. Your answers so far have been recorded.")
        }
        .alert("Questions Unavailable", isPresented: Binding(
            get: { engine.contentError != nil },
            set: { if !$0 { engine.dismissContentError() } }
        )) {
            Button("OK") { engine.dismissContentError() }
        } message: {
            Text(engine.contentError?.localizedDescription ?? "The question content could not be loaded.")
        }
        .onAppear {
            if let initialTestID, case .lobby = engine.phase {
                engine.startExam(testID: initialTestID)
            }
        }
    }

    private func openFlashcards() {
        navigationPath.append(HomeNavigationDestination.flashcards)
    }

    private func openMatchGame() {
        navigationPath.append(HomeNavigationDestination.matchGame)
    }

    private func openBookmarks() {
        navigationPath.append(HomeNavigationDestination.bookmarks)
    }

    private func openHighlights() {
        guard handbookDependencies != nil else { return }
        navigationPath.append(HomeNavigationDestination.highlights)
    }

    private func openPerformance() {
        dependencies.performance.refresh()
        navigationPath.append(HomeNavigationDestination.performance)
    }

    private func performRecommendation(_ action: RecommendedAction, _ concept: ConceptPerformance) {
        switch action {
        case .readHandbook:
            navigationPath.append(HomeNavigationDestination.handbookConcept(concept.id))
        case .reviewFlashcards:
            navigationPath.append(FlashcardDeck.concept(ids: conceptIDs(for: concept), title: concept.displayName))
        case .practiceQuestions:
            navigationPath = NavigationPath()
            engine.startTargetedPractice(conceptIDs: conceptIDs(for: concept), questionCount: 10)
        case .takeMiniQuiz:
            navigationPath = NavigationPath()
            engine.startTargetedPractice(conceptIDs: conceptIDs(for: concept), questionCount: 6)
        }
    }

    private func conceptIDs(for root: ConceptPerformance) -> [String] {
        let byID = Dictionary(uniqueKeysWithValues: dependencies.performance.report.concepts.map { ($0.id, $0) })
        var result: [String] = []
        var pending = [root.id]
        var seen = Set<String>()
        while let id = pending.popLast(), seen.insert(id).inserted {
            result.append(id)
            pending.append(contentsOf: byID[id]?.childIDs ?? [])
        }
        return result
    }

    @ViewBuilder
    private func handbookDestination(conceptID: String) -> some View {
        if let handbookDependencies,
           let performance = dependencies.performance.report.concepts.first(where: { $0.id == conceptID }),
           let reference = performance.handbookReferences.first,
           let chapter = handbookDependencies.catalog.chapters.first(where: { $0.contentID == reference.chapterId }) {
            let sectionIndex = chapter.sections.firstIndex { $0.id == reference.sectionId }
            ChapterView(chapter: chapter, dependencies: handbookDependencies, initialSectionIndex: sectionIndex, initialBlockID: reference.blockIds.first)
        } else {
            ContentUnavailableView("Reading unavailable", systemImage: "book.closed", description: Text("No handbook section is mapped to this topic."))
        }
    }

    private func quitQuiz() {
        engine.returnToLobby()
        onQuitQuiz?()
    }

    private func returnHome() {
        engine.returnToLobby()
        onReturnHome?()
    }

    private var isShowingQuestion: Bool {
        if case .question = engine.phase {
            return true
        }
        return false
    }

    private var shouldShowTabBar: Bool {
        engine.phase == .lobby && navigationPath.isEmpty
    }
}

private enum HomeNavigationDestination: Hashable {
    case flashcards
    case matchGame
    case bookmarks
    case highlights
    case performance
    case handbookConcept(String)
}
