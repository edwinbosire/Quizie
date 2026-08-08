import SwiftUI

struct QuizQuestionView: View {
    let engine: QuizEngine
    let questionIndex: Int

    @State private var showOptionsSheet = false
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
    
    var isBookmarked: Bool {
        guard let q = question else { return false }
        return bookmarkedQuestions.contains(q.id)
    }

    var body: some View {
		VStack(spacing: 0) {
			// Top bar: timer + progress + options
			QuizTopBar(engine: engine, onOptionsPressed: { showOptionsSheet = true })

			// Progress track
			QuizProgressBar(current: questionIndex + 1, total: engine.totalQuestions)

			if let question {
				QuestionView(engine: engine, question: question, questionIndex: questionIndex)
			}
		}
        .sheet(isPresented: $showOptionsSheet, onDismiss: presentPendingAlert) {
            QuizOptionsSheet(
                question: question,
                isBookmarked: isBookmarked,
                onRestart: { pendingAlert = .restart },
                onQuit: { pendingAlert = .quit },
                onToggleBookmark: toggleBookmark
            )
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
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
                    secondaryButton: .destructive(Text("Quit")) { engine.returnToLobby() }
                )
            }
        }
    }

    private func presentPendingAlert() {
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

private struct QuestionView: View {
	let engine: QuizEngine
	let question: QuizQuestion
	let questionIndex: Int
	var body: some View {
		ScrollView {
			VStack(spacing: 0) {
				// Question card
				QuestionCard(question: question, questionIndex: questionIndex)
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

// MARK: - Top Bar (timer + question count + options)
