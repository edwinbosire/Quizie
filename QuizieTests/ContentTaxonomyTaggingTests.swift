import Foundation
import Testing
@testable import BritReady__Life_in_UK_Test

@MainActor
struct ContentTaxonomyTaggingTests {
    @Test("Every bundled question has valid taxonomy metadata")
    func bundledQuestionsAreTagged() throws {
        let taxonomy = try BundleConceptTaxonomyRepository().taxonomy()
        let questionsURL = try #require(Bundle.main.url(forResource: "questions", withExtension: "json"))
        let questionsDocument = try JSONDecoder().decode(RawQuestionsFile.self, from: Data(contentsOf: questionsURL))
        let concepts = Set(taxonomy.concepts.map(\.id))
        let entities = Set(taxonomy.entities.map(\.id))
        let questions = try BundleQuestionRepository().questions(count: .max, seed: "taxonomy-integrity")

        #expect(questionsDocument.schemaVersion == 1)
        #expect(questionsDocument.taxonomyVersion == taxonomy.taxonomyVersion)
        #expect(questions.count == 1_014)
        for question in questions {
            #expect(!question.taxonomy.conceptIds.isEmpty, "Question \(question.id) has no concepts")
            #expect(question.taxonomy.primaryConceptId.map(question.taxonomy.conceptIds.contains) == true, "Question \(question.id) has an invalid primary concept")
            #expect(question.taxonomy.conceptIds.allSatisfy(concepts.contains), "Question \(question.id) references an unknown concept")
            #expect(question.taxonomy.entityIds.allSatisfy(entities.contains), "Question \(question.id) references an unknown entity")
        }
    }

    @Test("Quiz source resolves its taxonomy and handbook paragraph")
    func quizSourceResolvesHandbookPassage() throws {
        let taxonomy = try BundleConceptTaxonomyRepository().taxonomy()
        let questions = try BundleQuestionRepository().questions(count: .max, seed: "taxonomy-source")
        let chapters = try BundleHandbookRepository().document().chapters
        let resolver = QuizQuestionSourceResolver(chapters: chapters, taxonomyTagger: TaxonomyTagResolver(taxonomy: taxonomy))
        let question = try #require(questions.first { $0.id == "350" })
        let source = try #require(resolver.source(for: question))

        #expect(source.taxonomyPath == ["British History", "The Stuarts", "English Civil War"])
        #expect(source.chapterID == "chapter_03")
        #expect(source.sectionID == "section_03_03")
        #expect(source.chapterNumber == "Chapter 3")
        #expect(source.sectionTitle == "The Tudors and Stuarts")
        #expect(source.blockID == "section_03_03_block_045")
        #expect(source.passage?.contains("began in 1642") == true)
    }

    @Test("Quiz hints include lists attached to the relevant paragraph")
    func quizHintIncludesAttachedList() throws {
        let taxonomy = try BundleConceptTaxonomyRepository().taxonomy()
        let questions = try BundleQuestionRepository().questions(count: .max, seed: "taxonomy-list-source")
        let chapters = try BundleHandbookRepository().document().chapters
        let resolver = QuizQuestionSourceResolver(chapters: chapters, taxonomyTagger: TaxonomyTagResolver(taxonomy: taxonomy))
        let question = try #require(questions.first { $0.id == "202" })
        let source = try #require(resolver.source(for: question))
        let listItems = source.hintBlocks.flatMap { block -> [String] in
            if case .bulletList(let items) = block.content { return items }
            return []
        }

        #expect(source.passage?.contains("The denominations (values) of currency are:") == true)
        #expect(listItems.contains { $0.contains("coins:") })
        #expect(listItems.contains { $0.contains("notes: £5, £10, £20, £50") })
    }

    @Test("Every bundled question resolves a handbook source and hint")
    func allQuizQuestionsResolveHandbookSources() throws {
        let taxonomy = try BundleConceptTaxonomyRepository().taxonomy()
        let questions = try BundleQuestionRepository().questions(count: .max, seed: "taxonomy-all-sources")
        let chapters = try BundleHandbookRepository().document().chapters
        let resolver = QuizQuestionSourceResolver(chapters: chapters, taxonomyTagger: TaxonomyTagResolver(taxonomy: taxonomy))

        for question in questions {
            let source = resolver.source(for: question)
            #expect(source != nil, "Question \(question.id) has no handbook source")
            #expect(source?.hasHint == true, "Question \(question.id) has no handbook hint")
        }
    }

    @Test("Guide flashcards inherit their question taxonomy")
    func guideCardsInheritTags() throws {
        let questions = try BundleQuestionRepository().questions(count: .max, seed: "taxonomy-guide")
        let cards = questions.map(Flashcard.init(question:))

        #expect(cards.count == 1_014)
        for (question, card) in zip(questions, cards) {
            #expect(card.taxonomy == question.taxonomy)
            #expect(!card.taxonomy.conceptIds.isEmpty)
        }
        let overseasCard = try #require(cards.first { $0.id == "guide-1" })
        #expect(overseasCard.taxonomy.primaryConceptId == "uk-identity-and-geography.british-overseas-territories")
    }

    @Test("Generated flashcards resolve taxonomy from cited blocks")
    func generatedCardsUseSourceBlocks() throws {
        let taxonomy = try BundleConceptTaxonomyRepository().taxonomy()
        let tagger = TaxonomyTagResolver(taxonomy: taxonomy)
        let blockID = "section_03_02_block_012"
        let blockTags = tagger.tags(forBlockIDs: [blockID])
        let context = FlashcardGenerationContext(
            chapter: "3: History",
            section: "The Middle Ages",
            selection: "Magna Carta",
            context: "Magna Carta",
            blocks: [FlashcardContextBlock(id: blockID, text: "Magna Carta", isSelected: true, taxonomy: blockTags)],
            maxCards: 1,
            taxonomyVersion: taxonomy.taxonomyVersion,
            taxonomy: blockTags
        )

        #expect(context.taxonomy(for: [blockID]).conceptIds.contains("history.middle-ages.magna-carta"))
    }

    @Test("Every handbook section maps to targetable practice questions")
    func handbookSectionsMapToQuestions() throws {
        let taxonomy = try BundleConceptTaxonomyRepository().taxonomy()
        let tagger = TaxonomyTagResolver(taxonomy: taxonomy)
        let questions = try BundleQuestionRepository().questions(count: .max, seed: "section-revision")
        let chapters = try BundleHandbookRepository().document().chapters
        let sourceResolver = QuizQuestionSourceResolver(chapters: chapters, taxonomyTagger: tagger)
        let questionsBySection = Dictionary(grouping: questions.compactMap { question in sourceResolver.source(for: question).map { ($0.sectionID, question) } }, by: \.0)

        for section in chapters.flatMap(\.sections) {
            let conceptIDs = tagger.conceptIDs(forSectionID: section.id)
            #expect(!conceptIDs.isEmpty, "Section \(section.id) has no revision concepts")
            #expect(questionsBySection[section.id]?.isEmpty == false, "Section \(section.id) has no targeted practice questions")
        }
    }

    @Test("Section practice excludes questions sourced from other handbook sections")
    func sectionPracticeUsesExactSourceSection() throws {
        let taxonomy = try BundleConceptTaxonomyRepository().taxonomy()
        let tagger = TaxonomyTagResolver(taxonomy: taxonomy)
        let chapters = try BundleHandbookRepository().document().chapters
        let resolver = QuizQuestionSourceResolver(chapters: chapters, taxonomyTagger: tagger)
        let sectionID = "section_01_03"
        let history = LearningEventHistory(store: InMemoryLearningEventStore(), issues: PersistenceIssueCenter())
        let engine = QuizEngine(questionRepository: BundleQuestionRepository(), learningEvents: history, questionSourceResolver: resolver)

        engine.startTargetedPractice(conceptIDs: tagger.conceptIDs(forSectionID: sectionID), sectionID: sectionID, questionCount: 10)

        let questions = try #require(engine.session?.questions)
        #expect(!questions.isEmpty)
        #expect(questions.allSatisfy { resolver.source(for: $0)?.sectionID == sectionID })
        let question = try #require(engine.currentQuestion)
        engine.toggleChoice(0, isMultiSelect: question.isMultiSelect)
        engine.submitAndAdvance()
        #expect(history.questionAttempts.first?.source == .sectionPractice)
        engine.stopTimer()
    }

    @Test("Saved custom flashcards retain taxonomy")
    func savedCardsRetainTags() {
        let memory = FlashcardMemory(store: InMemoryFlashcardMemoryStore(), issues: PersistenceIssueCenter())
        let tags = ContentTaxonomyTags(primaryConceptId: "history.middle-ages.magna-carta", conceptIds: ["history.middle-ages.magna-carta"], entityIds: ["law.magna-carta"])
        let draft = FlashcardDraft(generatedCard: GeneratedFlashcard(question: "When was Magna Carta agreed?", answer: "1215", sourceBlockIds: ["block"], taxonomy: tags))

        FlashcardDraftApproval.save([draft], chapterNumber: 3, to: memory)

        #expect(memory.customCards.first?.taxonomy == tags)
        #expect(memory.customCards.first?.flashcard.taxonomy == tags)
    }

    @Test("Manually authored flashcards receive deterministic taxonomy")
    func manualCardsAreTagged() throws {
        let tagger = TaxonomyTagResolver(taxonomy: try BundleConceptTaxonomyRepository().taxonomy())
        let tags = tagger.tags(for: "When was Magna Carta agreed? 1215", chapter: 3)

        #expect(tags.conceptIds.contains("history.middle-ages.magna-carta"))
        #expect(tags.entityIds.contains("law.magna-carta"))
        #expect(!tagger.tags(for: "My own revision prompt", chapter: nil).conceptIds.isEmpty)
    }
}
