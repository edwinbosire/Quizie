import SwiftUI

struct QuizQuestionView: View {
    let engine: QuizEngine
    let questionIndex: Int
    var questionSourceResolver: QuizQuestionSourceResolver = .empty
    var onQuit: () -> Void = {}

    @State private var presentedSheet: QuizQuestionSheet?
    @State private var pendingHintSource: QuizQuestionSource?
    @State private var pendingAlert: QuizQuestionAlert?
    @State private var presentedAlert: QuizQuestionAlert?
    @AppStorage(QuestionBookmarks.storageKey) private var bookmarkedQuestionsData = Data()
    
    private var bookmarkedQuestions: Set<String> {
        QuestionBookmarks.ids(from: bookmarkedQuestionsData)
    }

    var question: QuizQuestion? { engine.session?.questions[safe: questionIndex] }
    var questionSource: QuizQuestionSource? { question.flatMap(questionSourceResolver.source(for:)) }
    
    var isBookmarked: Bool {
        guard let q = question else { return false }
        return bookmarkedQuestions.contains(q.id)
    }

    var body: some View {
		VStack(spacing: 0) {
			// Top bar: timer + progress + options
			QuizTopBar(engine: engine, onOptionsPressed: { presentedSheet = .options }, onClosePressed: { presentedAlert = .quit })

			// Progress track
			if let session = engine.session {
				QuizProgressBar(questions: session.questions, answers: session.answers, currentIndex: questionIndex)
			}

			if let question {
				QuestionView(engine: engine, question: question, questionIndex: questionIndex, source: questionSource, onShowHint: { presentedSheet = .hint($0) })
			}
		}
        .sheet(item: $presentedSheet, onDismiss: presentPendingPresentation) { sheet in
            switch sheet {
            case .options:
                QuizOptionsSheet(
                    source: questionSource,
                    isBookmarked: isBookmarked,
                    onShowHint: { pendingHintSource = $0 },
                    onRestart: { pendingAlert = .restart },
                    onToggleBookmark: toggleBookmark
                )
                .presentationDetents([.height(224)])
                .presentationDragIndicator(.visible)
            case .hint(let source):
                QuizHintSheet(source: source)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .alert(item: $presentedAlert) { alert in
            switch alert {
            case .restart:
                Alert(
                    title: Text(engine.isStreakMode ? "Restart Streak?" : "Restart Quiz?"),
                    message: Text(engine.isStreakMode ? "Your current streak will be lost and you’ll start again from zero." : "Your current progress will be lost permanently. This will reset all answers and restart the timer."),
                    primaryButton: .cancel(),
                    secondaryButton: .destructive(Text("Restart")) { engine.restartCurrentMode() }
                )
            case .quit:
                Alert(
                    title: Text("Quit Quiz?"),
                    message: Text("Your current progress will be lost permanently. You can start a new quiz from the lobby."),
                    primaryButton: .cancel(Text("Continue")),
                    secondaryButton: .destructive(Text("Quit"), action: onQuit)
                )
            }
        }
    }

    private func presentPendingPresentation() {
        if let pendingHintSource {
            self.pendingHintSource = nil
            presentedSheet = .hint(pendingHintSource)
            return
        }
        presentedAlert = pendingAlert
        pendingAlert = nil
    }
    
    private func toggleBookmark() {
        guard let q = question else { return }
        var bookmarks = bookmarkedQuestions
        if bookmarks.contains(q.id) {
            bookmarks.remove(q.id)
        } else {
            bookmarks.insert(q.id)
        }
        bookmarkedQuestionsData = QuestionBookmarks.data(for: bookmarks)
    }
}

private enum QuizQuestionAlert: String, Identifiable {
    case restart
    case quit

    var id: String { rawValue }
}

private enum QuizQuestionSheet: Identifiable {
    case options
    case hint(QuizQuestionSource)

    var id: String {
        switch self {
        case .options: return "options"
        case .hint(let source): return "hint-\(source.id)"
        }
    }
}

private struct QuestionView: View {
	let engine: QuizEngine
	let question: QuizQuestion
	let questionIndex: Int
	let source: QuizQuestionSource?
	let onShowHint: (QuizQuestionSource) -> Void
	var body: some View {
		ScrollView {
			VStack(spacing: 0) {
				// Question card
				QuestionCard(question: question, questionIndex: questionIndex, totalQuestions: engine.totalQuestions, source: source, onShowHint: onShowHint)
					.frame(minHeight: 200)
					.padding(.horizontal, 16)
					.padding(.vertical, 20)
					.staggered(0.1)

				// Choice options
				ChoicesView(engine: engine, question: question)
					.padding(.horizontal, 16)
					.padding(.top, 16)
					.staggered(0.2)

				// Submit button
				SubmitButton(engine: engine, question: question)
					.padding(.horizontal, 16)
					.padding(.top, 20)
					.padding(.bottom, 40)
					.staggered(0.4)
			}
		}
		.background(Color.hbBackground)
	}
}

// MARK: - Previews

#Preview("Quiz Question") {
    NavigationStack {
        QuizQuestionView(engine: PreviewQuizEngine.sampleEngine, questionIndex: 0)
    }
}

#Preview("Quiz Question - Multi-Select") {
    QuizQuestionView(engine: PreviewQuizEngine.multiSelectEngine, questionIndex: 1)
}

#Preview("Quiz Question - Time Warning") {
    QuizQuestionView(engine: PreviewQuizEngine.timeWarningEngine, questionIndex: 0)
}

// MARK: - Top Bar (timer + question count + options)
