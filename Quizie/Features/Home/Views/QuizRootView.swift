import SwiftUI

/// Root view that coordinates all quiz phases via QuizEngine
struct QuizRootView: View {
    let initialTestID: String?
    private let dependencies: QuizFeatureDependencies
    @StateObject private var engine: QuizEngine

    init(
        dependencies: QuizFeatureDependencies,
        initialTestID: String? = nil,
        configuration: QuizConfiguration = .practice
    ) {
        self.dependencies = dependencies
        self.initialTestID = initialTestID
        _engine = StateObject(wrappedValue: QuizEngine(
            configuration: configuration,
            questionRepository: dependencies.questions,
            attemptStore: dependencies.attempts,
            clock: dependencies.clock,
            scheduler: dependencies.scheduler
        ))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch engine.phase {
                case .lobby:
                    QuizLobbyView(engine: engine, attemptHistory: dependencies.attempts)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal: .move(edge: .leading)
                        ))

                case .question(let idx):
                    QuizQuestionView(engine: engine, questionIndex: idx)
                        .id(idx)   // force view refresh on index change
                        .navigationBarHidden(true)
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
}
