//
//  HandbookReaderQuizApp.swift
//  HandbookReaderQuiz
//
//  Created by Edwin Bosire on 28/03/2026.
//

import SwiftUI
import SwiftData

@main
struct HandbookReaderQuizApp: App {
    var body: some Scene {
        WindowGroup {
			RootTabView()
        }
        .modelContainer(for: [ExamAttempt.self, ReadingProgress.self, Highlight.self])
    }
}

struct RootTabView: View {
	@AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
	var body: some View {
		if hasCompletedOnboarding {
			TabView {
				Tab("Home", systemImage: "square.grid.2x2") {
					QuizRootView()
				}

				Tab("Tests", systemImage: "sparkle.text.clipboard") {
					TestsView()
				}

				Tab("Handbook", systemImage: "checklist") {
					NavigationStack {
						HandbookView()
					}
				}

				Tab("Search", systemImage: "magnifyingglass", role: .search) {
					SearchView()
				}
			}
			.tint(Color.hbAccent)

		} else {
			OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
		}
	}
}
