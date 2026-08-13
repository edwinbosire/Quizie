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
    @AppStorage("bookmarkedQuestions") private var bookmarkedQuestionsData = Data()
    
    private var bookmarkedQuestions: Set<String> {
        get {
            (try? JSONDecoder().decode(Set<String>.self, from: bookmarkedQuestionsData)) ?? []
        }
    }
    
    private func updateBookmarks(_ bookmarks: Set<String>) {
        if let data = try? JSONEncoder().encode(bookmarks) {
            bookmarkedQuestionsData = data
        }
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
			QuizTopBar(engine: engine, onOptionsPressed: { presentedSheet = .options })

			// Progress track
			QuizProgressBar(current: questionIndex + 1, total: engine.totalQuestions)

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
                    onQuit: { pendingAlert = .quit },
                    onToggleBookmark: toggleBookmark
                )
                .presentationDetents([.height(questionSource?.hasHint == true ? 280 : 224)])
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
                    title: Text("Restart Quiz?"),
                    message: Text("Your current progress will be lost permanently. This will reset all answers and restart the timer."),
                    primaryButton: .cancel(),
                    secondaryButton: .destructive(Text("Restart")) { engine.startExam() }
                )
            case .quit:
                Alert(
                    title: Text("Quit Quiz?"),
                    message: Text("Your current progress will be lost permanently. You can start a new quiz from the lobby."),
                    primaryButton: .cancel(),
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
        updateBookmarks(bookmarks)
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
				QuestionCard(question: question, questionIndex: questionIndex, source: source, onShowHint: onShowHint)
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
