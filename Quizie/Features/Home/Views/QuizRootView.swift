import SwiftUI

/// Root view that coordinates all quiz phases via QuizEngine
struct QuizRootView: View {
    let initialTestID: String?
    private let dependencies: QuizFeatureDependencies
    private let showsMainNavigationBar: Bool
    private let onOpenSearch: () -> Void
    private let onOpenHandbook: () -> Void
    private let onOpenSettings: () -> Void
    private let onQuitQuiz: (() -> Void)?
    @State private var engine: QuizEngine
    @State private var navigationPath: [HomeNavigationDestination] = []

    init(
        dependencies: QuizFeatureDependencies,
        initialTestID: String? = nil,
        configuration: QuizConfiguration = .practice,
        showsMainNavigationBar: Bool = false,
        onOpenSearch: @escaping () -> Void = {},
        onOpenHandbook: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {},
        onQuitQuiz: (() -> Void)? = nil
    ) {
        self.dependencies = dependencies
        self.initialTestID = initialTestID
        self.showsMainNavigationBar = showsMainNavigationBar
        self.onOpenSearch = onOpenSearch
        self.onOpenHandbook = onOpenHandbook
        self.onOpenSettings = onOpenSettings
        self.onQuitQuiz = onQuitQuiz
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
                        onOpenFlashcards: openFlashcards,
                        onOpenMatchGame: openMatchGame
                    )
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal: .move(edge: .leading)
                        ))

                case .question(let idx):
                    QuizQuestionView(engine: engine, questionIndex: idx, onQuit: quitQuiz)
                        .id(idx)   // force view refresh on index change
                        .navigationBarBackButtonHidden(true)
                        .ignoresSafeArea(.container, edges: .bottom)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))

                case .results:
                    QuizResultsView(engine: engine)
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
                    FlashcardsView(dependencies: dependencies)
                case .matchGame:
                    MatchGameView()
                }
            }
        }
        .toolbar(engine.phase == .lobby ? .visible : .hidden, for: .tabBar)
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
        navigationPath.append(.flashcards)
    }

    private func openMatchGame() {
        navigationPath.append(.matchGame)
    }

    private func quitQuiz() {
        engine.returnToLobby()
        onQuitQuiz?()
    }

    private var isShowingQuestion: Bool {
        if case .question = engine.phase {
            return true
        }
        return false
    }
}

private enum HomeNavigationDestination: Hashable {
    case flashcards
    case matchGame
}
