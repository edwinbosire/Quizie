import SwiftUI

/// Root view that coordinates all quiz phases via QuizEngine
struct QuizRootView: View {
    let initialTestID: String?
    private let dependencies: QuizFeatureDependencies
    private let handbookDependencies: HandbookFeatureDependencies?
    private let searchDependencies: SearchFeatureDependencies?
    private let onOpenSettings: () -> Void
    @State private var engine: QuizEngine
    @State private var navigationPath: [HomeNavigationDestination] = []

    init(
        dependencies: QuizFeatureDependencies,
        initialTestID: String? = nil,
        configuration: QuizConfiguration = .practice,
        handbookDependencies: HandbookFeatureDependencies? = nil,
        searchDependencies: SearchFeatureDependencies? = nil,
        onOpenSettings: @escaping () -> Void = {}
    ) {
        self.dependencies = dependencies
        self.initialTestID = initialTestID
        self.handbookDependencies = handbookDependencies
        self.searchDependencies = searchDependencies
        self.onOpenSettings = onOpenSettings
        _engine = State(initialValue: QuizEngine(
            configuration: configuration,
            questionRepository: dependencies.questions,
            attemptStore: dependencies.attempts,
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
                        onOpenSearch: openSearch,
                        onOpenHandbook: openHandbook,
                        onOpenFlashcards: openFlashcards,
                        onOpenMatchGame: openMatchGame,
                        onOpenSettings: onOpenSettings
                    )
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal: .move(edge: .leading)
                        ))

                case .question(let idx):
                    QuizQuestionView(engine: engine, questionIndex: idx)
                        .id(idx)   // force view refresh on index change
                        .navigationBarBackButtonHidden(true)
                        .toolbar(.hidden, for: .navigationBar)
                        .toolbar(.hidden, for: .tabBar)
                        .ignoresSafeArea(.container, edges: .bottom)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))

                case .results:
                    QuizResultsView(engine: engine)
                        .toolbar(.hidden, for: .tabBar)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing)
                        ))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: engine.phase.id)
            .navigationDestination(for: HomeNavigationDestination.self) { destination in
                switch destination {
                case .search:
                    if let searchDependencies {
                        SearchView(dependencies: searchDependencies)
                    }
                case .handbook:
                    if let handbookDependencies {
                        HandbookView(dependencies: handbookDependencies)
                            .navigationTitle("Handbook")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                case .flashcards:
                    FlashcardsView(dependencies: dependencies)
                case .matchGame:
                    MatchGameView()
                }
            }
        }
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

    private func openSearch() {
        guard searchDependencies != nil else { return }
        navigationPath.append(.search)
    }

    private func openHandbook() {
        guard handbookDependencies != nil else { return }
        navigationPath.append(.handbook)
    }

    private func openFlashcards() {
        navigationPath.append(.flashcards)
    }

    private func openMatchGame() {
        navigationPath.append(.matchGame)
    }
}

private enum HomeNavigationDestination: Hashable {
    case search
    case handbook
    case flashcards
    case matchGame
}
