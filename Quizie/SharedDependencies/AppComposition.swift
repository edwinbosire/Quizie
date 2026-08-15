import Foundation
import SwiftData

@MainActor
struct QuizFeatureDependencies {
    let questions: any QuestionRepository
    let attempts: AttemptHistory
    let learningEvents: LearningEventHistory
    let performance: PerformanceReportService
    let clock: any QuizClock
    let scheduler: any QuizScheduler
    let questionSources: QuizQuestionSourceResolver
}

@MainActor
struct TestsFeatureDependencies {
    let quiz: QuizFeatureDependencies
    let flashcards: FlashcardFeatureDependencies
}

@MainActor
struct FlashcardFeatureDependencies {
    let catalog: FlashcardCatalog
    let memory: FlashcardMemory
    let clock: any QuizClock
    let aiInference: any AIInferenceService
    var taxonomyTagger: TaxonomyTagResolver = .empty
}

@MainActor
struct HandbookReaderDependencies {
    let catalog: HandbookCatalog
    let progress: ReadingProgressLibrary
    let highlights: HighlightLibrary
    let aiInference: any AIInferenceService
    let flashcardMemory: FlashcardMemory
    var taxonomyTagger: TaxonomyTagResolver = .empty
}

@MainActor
struct HandbookFeatureDependencies {
    let reader: HandbookReaderDependencies

    var catalog: HandbookCatalog { reader.catalog }
    var progress: ReadingProgressLibrary { reader.progress }
    var highlights: HighlightLibrary { reader.highlights }

    init(catalog: HandbookCatalog, progress: ReadingProgressLibrary, highlights: HighlightLibrary, flashcards: FlashcardFeatureDependencies) {
        reader = HandbookReaderDependencies(catalog: catalog, progress: progress, highlights: highlights, aiInference: flashcards.aiInference, flashcardMemory: flashcards.memory, taxonomyTagger: flashcards.taxonomyTagger)
    }
}

@MainActor
struct SearchFeatureDependencies {
    let service: any HandbookSearchServing
    let reader: HandbookReaderDependencies

    var catalog: HandbookCatalog { reader.catalog }
    var progress: ReadingProgressLibrary { reader.progress }
    var highlights: HighlightLibrary { reader.highlights }

    init(
        service: any HandbookSearchServing,
        catalog: HandbookCatalog,
        progress: ReadingProgressLibrary,
        highlights: HighlightLibrary,
        flashcards: FlashcardFeatureDependencies
    ) {
        self.service = service
        reader = HandbookReaderDependencies(catalog: catalog, progress: progress, highlights: highlights, aiInference: flashcards.aiInference, flashcardMemory: flashcards.memory, taxonomyTagger: flashcards.taxonomyTagger)
    }
}

/// The only production composition root. It constructs concrete infrastructure
/// and exposes feature-scoped dependency values; it is not a service locator.
@MainActor
struct AppDependencies {
    let modelContainer: ModelContainer
    let quiz: QuizFeatureDependencies
    let tests: TestsFeatureDependencies
    let flashcards: FlashcardFeatureDependencies
    let handbook: HandbookFeatureDependencies
    let search: SearchFeatureDependencies
    let performance: PerformanceReportService
    let persistenceIssues: PersistenceIssueCenter

    static func production(bundle: Bundle = .main) throws -> AppDependencies {
        let container = try AppPersistence.makeContainer()
        let taxonomy = try BundleConceptTaxonomyRepository(bundle: bundle).taxonomy()
        return assemble(
            container: container,
            questions: BundleQuestionRepository(bundle: bundle),
            handbook: BundleHandbookRepository(bundle: bundle),
            taxonomy: taxonomy,
            taxonomyTagger: TaxonomyTagResolver(taxonomy: taxonomy),
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
        taxonomy: ConceptTaxonomy? = nil,
        taxonomyTagger: TaxonomyTagResolver = .empty,
        persistence: PersistenceServices,
        clock: any QuizClock,
        scheduler: any QuizScheduler
    ) -> AppDependencies {
        let catalog = HandbookCatalog(repository: handbookRepository)
        let resolvedTaxonomy = taxonomy ?? ConceptTaxonomy(schemaVersion: 1, taxonomyVersion: "preview", handbookVersion: "preview", generatedAt: "", concepts: [], entities: [])
        let performance = PerformanceReportService(events: persistence.learningEvents, taxonomy: resolvedTaxonomy, cache: SwiftDataPerformanceSnapshotStore(context: container.mainContext))
        if let document = catalog.document {
            persistence.progress.reconcile(document: document)
            persistence.highlights.reconcile(document: document)
        }

        let quiz = QuizFeatureDependencies(
            questions: questions,
            attempts: persistence.attempts,
            learningEvents: persistence.learningEvents,
            performance: performance,
            clock: clock,
            scheduler: scheduler,
            questionSources: QuizQuestionSourceResolver(chapters: catalog.chapters, taxonomyTagger: taxonomyTagger)
        )
        let flashcards = FlashcardFeatureDependencies(
            catalog: FlashcardCatalog(repository: questions),
            memory: persistence.flashcards,
            clock: clock,
            aiInference: OpenAIInferenceService(),
            taxonomyTagger: taxonomyTagger
        )
        persistence.flashcards.importLegacyReviewEvents(for: flashcards.catalog.allCards(memory: flashcards.memory))
        let handbook = HandbookFeatureDependencies(
            catalog: catalog,
            progress: persistence.progress,
            highlights: persistence.highlights,
            flashcards: flashcards
        )
        return AppDependencies(
            modelContainer: container,
            quiz: quiz,
            tests: TestsFeatureDependencies(quiz: quiz, flashcards: flashcards),
            flashcards: flashcards,
            handbook: handbook,
            search: SearchFeatureDependencies(
                service: HandbookSearchService(repository: handbookRepository),
                catalog: catalog,
                progress: persistence.progress,
                highlights: persistence.highlights,
                flashcards: flashcards
            ),
            performance: performance,
            persistenceIssues: persistence.issues
        )
    }
}
