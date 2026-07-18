import SwiftUI

struct QuizQuestionView: View {
    @EnvironmentObject var engine: QuizEngine
    let questionIndex: Int

    @State private var animateSubmitButton = false
    @State private var showOptionsSheet = false
    @State private var showRestartAlert = false
    @State private var showQuitAlert = false
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
			QuizTopBar(onOptionsPressed: { showOptionsSheet = true })

			// Progress track
			QuizProgressBar(current: questionIndex + 1, total: engine.totalQuestions)

			if let question {
				QuestionView(question: question, questionIndex: questionIndex)
			}
		}
        .sheet(isPresented: $showOptionsSheet) {
            QuizOptionsSheet(
                question: question,
                isBookmarked: isBookmarked,
                onRestart: { showRestartAlert = true },
                onQuit: { showQuitAlert = true },
                onToggleBookmark: toggleBookmark
            )
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
        }
        .alert("Restart Quiz?", isPresented: $showRestartAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Restart", role: .destructive) {
                engine.startExam()
            }
        } message: {
            Text("Your current progress will be lost permanently. This will reset all answers and restart the timer.")
        }
        .alert("Quit Quiz?", isPresented: $showQuitAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Quit", role: .destructive) {
                engine.returnToLobby()
            }
        } message: {
            Text("Your current progress will be lost permanently. You can start a new quiz from the lobby.")
        }
        .onAppear {
            // Delay submit button animation by 3 seconds
            withAnimation(.bouncy.delay(1.05)) {
                animateSubmitButton = true
            }
        }
        .onChange(of: questionIndex) { _, _ in
            animateSubmitButton = false

            // Delay submit button animation by 3 seconds
            withAnimation(.bouncy.delay(1.05)) {
                animateSubmitButton = true
            }
        }
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

private struct QuestionView: View {
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
				ChoicesView(question: question)
					.padding(.horizontal, 16)
					.padding(.top, 16)
					.staggered(0.2)

				// Submit button
				SubmitButton(question: question)
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
