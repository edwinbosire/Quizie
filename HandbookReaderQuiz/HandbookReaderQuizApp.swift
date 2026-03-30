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
        .modelContainer(for: [ExamAttempt.self, ReadingProgress.self])
    }
}

struct RootTabView: View {
	@AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

	var body: some View {
		if hasCompletedOnboarding {
			TabView {
				NavigationStack {
					HandbookView()
				}
				.tabItem {
					Label("Handbook", systemImage: "book.fill")
				}

				QuizRootView()
					.tabItem {
						Label("Practice Test", systemImage: "pencil.and.list.clipboard")
					}
			}
			.tint(Color.hbAccent)
		} else {
			OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
		}
	}
}
