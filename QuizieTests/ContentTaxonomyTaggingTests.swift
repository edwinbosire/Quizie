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
