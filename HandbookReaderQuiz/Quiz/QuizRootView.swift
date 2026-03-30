import SwiftUI
import SwiftData

/// Root view that coordinates all quiz phases via QuizEngine
struct QuizRootView: View {
    @StateObject private var engine = QuizEngine()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Group {
                switch engine.phase {
                case .lobby:
                    QuizLobbyView()
                        .environmentObject(engine)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal: .move(edge: .leading)
                        ))

                case .question(let idx):
                    QuizQuestionView(questionIndex: idx)
                        .environmentObject(engine)
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
                    QuizResultsView()
                        .environmentObject(engine)
                        .toolbar(.hidden, for: .tabBar)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing)
                        ))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: engine.phase.id)
        }
        .alert("Time's Up!", isPresented: $engine.didTimeOut) {
            Button("See Results") { engine.finishExam() }
        } message: {
            Text("You've run out of time. Your answers so far have been recorded.")
        }
        .onAppear {
            engine.modelContext = modelContext
        }
    }
}

// MARK: - Phase Equatable for animation
extension QuizPhase: Equatable {
    static func == (lhs: QuizPhase, rhs: QuizPhase) -> Bool {
        switch (lhs, rhs) {
        case (.lobby, .lobby): return true
        case (.results, .results): return true
        case (.question(let a), .question(let b)): return a == b
        default: return false
        }
    }

    var id: String {
        switch self {
        case .lobby:           return "lobby"
        case .question(let i): return "q\(i)"
        case .results:         return "results"
        }
    }
}
