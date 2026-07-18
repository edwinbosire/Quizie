import Foundation
import SwiftData

@MainActor
struct QuizFeatureDependencies {
    let questions: any QuestionRepository
    let attempts: AttemptHistory
    let clock: any QuizClock
    let scheduler: any QuizScheduler
}

@MainActor
struct TestsFeatureDependencies {
    let quiz: QuizFeatureDependencies
}

@MainActor
struct HandbookFeatureDependencies {
    let catalog: HandbookCatalog
    let progress: ReadingProgressLibrary
    let highlights: HighlightLibrary
}

@MainActor
struct SearchFeatureDependencies {
    let service: any HandbookSearchServing
    let catalog: HandbookCatalog
    let progress: ReadingProgressLibrary
    let highlights: HighlightLibrary
}

/// The only production composition root. It constructs concrete infrastructure
/// and exposes feature-scoped dependency values; it is not a service locator.
@MainActor
struct AppDependencies {
    let modelContainer: ModelContainer
    let quiz: QuizFeatureDependencies
    let tests: TestsFeatureDependencies
    let handbook: HandbookFeatureDependencies
    let search: SearchFeatureDependencies
    let persistenceIssues: PersistenceIssueCenter

    static func production(bundle: Bundle = .main) throws -> AppDependencies {
        let container = try AppPersistence.makeContainer()
        return assemble(
            container: container,
            questions: BundleQuestionRepository(bundle: bundle),
            handbook: BundleHandbookRepository(bundle: bundle),
            persistence: PersistenceServices(container: container),
            clock: SystemQuizClock(),
            scheduler: SystemQuizScheduler()
        )
    }

    static func preview(
        questions: [QuizQuestion],
        chapters: [HandbookChapter],
        attempts: [ExamAttemptSnapshot] = [],
        progress: [ReadingProgressSnapshot] = [],
        highlights: [HighlightSnapshot] = []
    ) throws -> AppDependencies {
        let container = try AppPersistence.makeContainer(inMemory: true)
        return assemble(
            container: container,
            questions: InMemoryQuestionRepository(questions),
            handbook: InMemoryHandbookRepository(chapters),
            persistence: PersistenceServices(
                attemptStore: InMemoryExamAttemptStore(attempts: attempts),
                progressStore: InMemoryReadingProgressStore(records: progress),
                highlightStore: InMemoryHighlightStore(records: highlights)
            ),
            clock: SystemQuizClock(),
            scheduler: SystemQuizScheduler()
        )
    }

    static func preview(bundle: Bundle = .main) throws -> AppDependencies {
        let questions = try BundleQuestionRepository(bundle: bundle).questions(count: 24, seed: "preview")
        let chapters = try BundleHandbookRepository(bundle: bundle).document().chapters
        return try preview(questions: questions, chapters: chapters)
    }

    static func test(
        questions: [QuizQuestion],
        chapters: [HandbookChapter],
        clock: any QuizClock,
        scheduler: any QuizScheduler
    ) throws -> AppDependencies {
        let container = try AppPersistence.makeContainer(inMemory: true)
        return assemble(
            container: container,
            questions: InMemoryQuestionRepository(questions),
            handbook: InMemoryHandbookRepository(chapters),
            persistence: PersistenceServices(
                attemptStore: InMemoryExamAttemptStore(),
                progressStore: InMemoryReadingProgressStore(),
                highlightStore: InMemoryHighlightStore()
            ),
            clock: clock,
            scheduler: scheduler
        )
    }

    private static func assemble(
        container: ModelContainer,
        questions: any QuestionRepository,
        handbook handbookRepository: any HandbookRepository,
        persistence: PersistenceServices,
        clock: any QuizClock,
        scheduler: any QuizScheduler
    ) -> AppDependencies {
        let catalog = HandbookCatalog(repository: handbookRepository)
        if let document = catalog.document {
            persistence.progress.reconcile(document: document)
            persistence.highlights.reconcile(document: document)
        }

        let quiz = QuizFeatureDependencies(
            questions: questions,
            attempts: persistence.attempts,
            clock: clock,
            scheduler: scheduler
        )
        let handbook = HandbookFeatureDependencies(
            catalog: catalog,
            progress: persistence.progress,
            highlights: persistence.highlights
        )
        return AppDependencies(
            modelContainer: container,
            quiz: quiz,
            tests: TestsFeatureDependencies(quiz: quiz),
            handbook: handbook,
            search: SearchFeatureDependencies(
                service: HandbookSearchService(repository: handbookRepository),
                catalog: catalog,
                progress: persistence.progress,
                highlights: persistence.highlights
            ),
            persistenceIssues: persistence.issues
        )
    }
}
