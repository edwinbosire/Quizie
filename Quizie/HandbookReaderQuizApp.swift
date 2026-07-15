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
    private let container: ModelContainer
    private let persistence: PersistenceServices

    init() {
        do {
            let container = try AppPersistence.makeContainer()
            self.container = container
            self.persistence = PersistenceServices(container: container)
        } catch {
            fatalError("Unable to initialize persistence: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(dependencies: .live(), persistence: persistence)
        }
        .modelContainer(container)
    }
}

struct RootTabView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    private let dependencies: AppDependencies
    private let persistence: PersistenceServices
    @State private var handbookCatalog: HandbookCatalog

    init(dependencies: AppDependencies, persistence: PersistenceServices) {
        self.dependencies = dependencies
        self.persistence = persistence
        let catalog = HandbookCatalog(repository: dependencies.handbook)
        if let document = catalog.document {
            persistence.progress.reconcile(document: document)
            persistence.highlights.reconcile(document: document)
        }
        _handbookCatalog = State(initialValue: catalog)
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                TabView {
                    Tab("Home", systemImage: "square.grid.2x2") {
                        QuizRootView(questionRepository: dependencies.questions)
                    }

                    Tab("Tests", systemImage: "sparkle.text.clipboard") {
                        TestsView(questionRepository: dependencies.questions)
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
        .environment(handbookCatalog)
        .environment(persistence.attempts)
        .environment(persistence.progress)
        .environment(persistence.highlights)
        .environment(persistence.issues)
        .alert(item: Binding(
            get: { persistence.issues.issue },
            set: { if $0 == nil { persistence.issues.dismiss() } }
        )) { issue in
            Alert(title: Text("Unable to Save Data"), message: Text(issue.message), dismissButton: .default(Text("OK"), action: persistence.issues.dismiss))
        }
    }
}
