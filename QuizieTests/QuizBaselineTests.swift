import Foundation
import SwiftData
import Testing
@testable import BritReady__Life_in_UK_Test

struct FlashcardGenerationContextTests {
    private let chapter = HandbookChapter(
        id: 0,
        contentID: "chapter_01",
        number: "Chapter 1",
        title: "The values and principles of the UK",
        pillLabels: ["British values"],
        sections: []
    )

    @Test("A sentence selection includes its full block and adjacent blocks")
    func sentenceSelectionIncludesContext() throws {
        let section = makeSection([
            ("before", "People should respect the law."),
            ("selected", "British life is founded on democracy, the rule of law and individual liberty."),
            ("after", "Citizens should participate in their communities."),
            ("outside", "This block is not adjacent.")
        ])
        let source = section.blocks[1].plainText as NSString
        let selection = source.range(of: "democracy, the rule of law and individual liberty")

        let request = try #require(FlashcardGenerationContextBuilder.make(chapter: chapter, section: section, selectedBlockRange: 1...1, selectedTextRange: selection))

        #expect(request.chapter == "Chapter 1: The values and principles of the UK")
        #expect(request.section == "British values")
        #expect(request.selection == "democracy, the rule of law and individual liberty")
        #expect(request.blocks.map(\.id) == ["before", "selected", "after"])
        #expect(request.blocks.map(\.isSelected) == [false, true, false])
        #expect(request.context.contains("[selected] [selected]"))
        #expect(request.maxCards == 1)
    }

    @Test("Two selected blocks allow several cards without requesting a fixed batch")
    func twoBlocksScaleCardLimit() throws {
        let section = makeSection([
            ("one", "Parliament makes laws. MPs are elected."),
            ("two", "The government runs the country. The Prime Minister leads the government."),
            ("adjacent", "Local government provides local services.")
        ])

        let request = try #require(FlashcardGenerationContextBuilder.make(chapter: chapter, section: section, selectedBlockRange: 0...1))

        #expect(request.maxCards == 4)
        #expect(request.selection.contains("\n\n"))
        #expect(request.blocks.map(\.id) == ["one", "two", "adjacent"])
    }

    @Test("Large selections use a bounded semantic-card ceiling")
    func largeSelectionIsBounded() throws {
        let section = makeSection((0..<12).map { ("block-\($0)", "Testable fact number \($0).") })
        let request = try #require(FlashcardGenerationContextBuilder.make(chapter: chapter, section: section, selectedBlockRange: 0...11))
        #expect(request.maxCards == 8)
        #expect(request.blocks.count == 12)
    }

    @Test("Generation context encodes the complete architecture payload")
    func contextEncodingContainsRequiredFields() throws {
        let section = makeSection([("block", "Democracy is a fundamental principle.")])
        let request = try #require(FlashcardGenerationContextBuilder.make(chapter: chapter, section: section, selectedBlockRange: 0...0))
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        #expect(Set(object.keys) == ["chapter", "section", "selection", "context", "blocks", "maxCards", "taxonomyVersion", "taxonomy"])
    }

    @Test("Structured cards decode with source block IDs")
    func structuredResponseDecoding() throws {
        let data = Data(#"{"cards":[{"question":"What is a principle?","answer":"Democracy.","sourceBlockIds":["block"]}]}"#.utf8)
        let response = try JSONDecoder().decode(FlashcardGenerationResponse.self, from: data)
        #expect(response.cards == [GeneratedFlashcard(question: "What is a principle?", answer: "Democracy.", sourceBlockIds: ["block"])])
    }

    @Test("Features can generate cards through a provider-neutral inference service")
    func mockInferenceServiceGeneratesCards() async throws {
        let expected = [GeneratedFlashcard(question: "What is a principle?", answer: "Democracy.", sourceBlockIds: ["block"])]
        let service: any AIInferenceService = MockInferenceService(flashcards: expected)
        let context = FlashcardGenerationContext(
            chapter: "Chapter 1: The values and principles of the UK",
            section: "British values",
            selection: "Democracy is a fundamental principle.",
            context: "[block] [selected]\nDemocracy is a fundamental principle.",
            blocks: [FlashcardContextBlock(id: "block", text: "Democracy is a fundamental principle.", isSelected: true)],
            maxCards: 1
        )

        let cards = try await service.generateFlashcards(from: context)
        #expect(cards == expected)
    }

    @MainActor
    @Test("Generated drafts do not enter the deck until approved")
    func approvalIsThePersistenceBoundary() {
        let memory = FlashcardMemory(store: InMemoryFlashcardMemoryStore(), issues: PersistenceIssueCenter())
        let drafts = [FlashcardDraft(generatedCard: GeneratedFlashcard(question: "What is a principle?", answer: "Democracy.", sourceBlockIds: ["block"]))]

        #expect(memory.customCards.isEmpty)
        FlashcardDraftApproval.save(drafts, chapterNumber: 1, to: memory)
        #expect(memory.customCards.map(\.prompt) == ["What is a principle?"])
        #expect(memory.customCards.first?.sourceBlockIDs == ["block"])
        #expect(memory.customCards.first?.taxonomy.isEmpty == true)
    }

    @Test("Recall cards contain one clear target and one minimal answer")
    func recallCardStyleIsConcise() {
        #expect(FlashcardRecallStyle.isValid(question: "Who agreed Magna Carta?", answer: "King John."))
        #expect(!FlashcardRecallStyle.isValid(question: "Who agreed it? Why?", answer: "King John."))
        #expect(!FlashcardRecallStyle.isValid(question: "Who agreed Magna Carta?", answer: "King John agreed it after a prolonged dispute with powerful English barons at Runnymede."))
        #expect(!FlashcardRecallStyle.isValid(question: "Which TWO people agreed Magna Carta?", answer: "King John."))
        #expect(!FlashcardRecallStyle.isValid(question: "Which of these statements is correct?", answer: "Magna Carta was agreed in 1215."))
        #expect(!FlashcardRecallStyle.isValid(question: "Who agreed it?", answer: "King John."))
        #expect(!FlashcardRecallStyle.isValid(question: "Who agreed Magna Carta and when?", answer: "King John"))
        #expect(!FlashcardRecallStyle.isValid(question: "Who agreed Magna Carta?", answer: "King John and the barons"))
        #expect(!FlashcardRecallStyle.isValid(question: "Who was John Constable?", answer: "A landscape painter"))
        #expect(!FlashcardRecallStyle.isValid(question: "Who is Sir Edward Elgar (1857–1934)?", answer: "A musician"))
        #expect(!FlashcardRecallStyle.isValid(question: "Was Magna Carta agreed in 1215?", answer: "True"))
        #expect(!FlashcardRecallStyle.isValid(question: "What is another name for EU laws?", answer: "All of these"))
        #expect(!FlashcardRecallStyle.isValid(question: "Which was Churchill's famous speech?", answer: "All of the these"))
        #expect(!FlashcardRecallStyle.isValid(question: "What happens after an MP resigns?", answer: "A by-election is held"))
        #expect(FlashcardRecallStyle.isValid(question: "When was Magna Carta agreed?", answer: "1215"))
        #expect(FlashcardRecallStyle.isValid(question: "Who developed the World Wide Web?", answer: "Sir Tim Berners-Lee"))
    }

    private func makeSection(_ values: [(String, String)]) -> HandbookSection {
        HandbookSection(id: "section_01", title: "British values", blocks: values.map { ContentBlock(id: $0.0, content: .paragraph($0.1)) })
    }
}

struct BundledFlashcardConverterTests {
    @Test("Direct recall questions remain concise guide cards")
    func directRecallQuestion() throws {
        let conversion = BundledFlashcardConverter.convert(question(id: "direct", prompt: "When was Magna Carta agreed?", choices: ["1215", "1066"], correctIndices: [0]))
        let card = try #require(conversion.card)

        #expect(card.prompt == "When was Magna Carta agreed?")
        #expect(card.answer == "1215")
        #expect(conversion.auditEntry == nil)
    }

    @Test("Safe multiple-choice scaffolding is removed")
    func repairsChoiceDependentPrompt() throws {
        let conversion = BundledFlashcardConverter.convert(question(id: "venue", prompt: "Which of these venues is located in Scotland?", choices: ["The SECC", "The O2"], correctIndices: [0]))
        let card = try #require(conversion.card)

        #expect(card.prompt == "Where is the SECC located?")
        #expect(card.answer == "Scotland")
        #expect(conversion.auditEntry?.outcome == .repaired)
        #expect(conversion.auditEntry?.issues.contains(.nonAtomicPrompt) == true)
    }

    @Test("Biographical paragraphs are inverted to recall the person's name")
    func repairsBiographicalAnswer() throws {
        let conversion = BundledFlashcardConverter.convert(question(id: "constable", prompt: "Who was John Constable?", choices: ["A landscape painter famous for views of Dedham Vale", "A scientist"], correctIndices: [0]))
        let card = try #require(conversion.card)

        #expect(card.prompt == "Who was a landscape painter famous for views of Dedham Vale?")
        #expect(card.answer == "John Constable")
        #expect(conversion.auditEntry?.outcome == .repaired)
    }

    @Test("Multi-answer quiz questions are flagged and excluded")
    func excludesMultiAnswerQuestion() {
        let conversion = BundledFlashcardConverter.convert(question(id: "territories", prompt: "Which TWO are British Overseas Territories?", choices: ["The Falkland Islands", "St Helena", "Ireland"], correctIndices: [0, 1]))

        #expect(conversion.card == nil)
        #expect(conversion.auditEntry?.outcome == .excluded)
        #expect(conversion.auditEntry?.issues.contains(.multipleAnswers) == true)
        #expect(conversion.auditEntry?.issues.contains(.nonMinimalAnswer) == true)
    }

    private func question(id: String, prompt: String, choices: [String], correctIndices: Set<Int>) -> QuizQuestion {
        QuizQuestion(id: id, question: prompt, choices: choices, correctIndices: correctIndices, isMultiSelect: correctIndices.count > 1, year: "", category: 3, explanationLink: "", taxonomy: ContentTaxonomyTags(conceptIds: ["history"]))
    }
}

@MainActor
struct QuizScoringTests {
    @Test("Score counts only exact correct answers")
    func scoreCountsCorrectAnswers() {
        let questions = TestFixtures.questions(count: 3)
        var session = ExamSession(questions: questions, startedAt: TestFixtures.startDate)

        session.submit(answer: [0], for: questions[0])
        session.submit(answer: [1], for: questions[1])
        session.submit(answer: [0], for: questions[2])

        #expect(session.score == 2)
        #expect(session.answeredCount == 3)
        #expect(abs(session.percentage - (200.0 / 3.0)) < 0.000_001)
    }

    @Test("Pass threshold is inclusive", arguments: [17, 18, 19])
    func passThreshold(score: Int) {
        let configuration = QuizConfiguration.practice
        let questions = TestFixtures.questions(count: configuration.questionCount)
        var session = ExamSession(configuration: configuration, questions: questions, startedAt: TestFixtures.startDate)

        for question in questions.prefix(score) {
            session.submit(answer: question.correctIndices, for: question)
        }

        #expect(session.score == score)
        #expect(session.passed == (score >= configuration.passMarkCount))
    }

    @Test("Multi-select requires the complete exact selection")
    func multiSelectUsesExactSetEquality() {
        let question = TestFixtures.question(id: "multi", correctIndices: [0, 2])
        var session = ExamSession(questions: [question], startedAt: TestFixtures.startDate)

        session.submit(answer: [0], for: question)
        #expect(session.answers[question.id]?.isCorrect == false)

        session.submit(answer: [0, 1, 2], for: question)
        #expect(session.answers[question.id]?.isCorrect == false)

        session.submit(answer: [2, 0], for: question)
        #expect(session.answers[question.id]?.isCorrect == true)
        #expect(session.score == 1)
    }

    @Test("Seeded question sets are repeatable")
    func seededQuestionSetIsDeterministic() throws {
        let repository = InMemoryQuestionRepository(TestFixtures.questions(count: 10))

        let first = try repository.questions(count: 5, seed: "practice-test-4").map(\.id)
        let second = try repository.questions(count: 5, seed: "practice-test-4").map(\.id)

        #expect(first == ["q-2", "q-7", "q-0", "q-3", "q-4"])
        #expect(second == first)
    }
}

@MainActor
struct FlashcardSessionTests {
    private let cards = [
        Flashcard(id: "one", prompt: "First?", answer: "First answer", topic: "Chapter 1"),
        Flashcard(id: "two", prompt: "Second?", answer: "Second answer", topic: "Chapter 2"),
        Flashcard(id: "three", prompt: "Third?", answer: "Third answer", topic: "Chapter 3")
    ]

    @Test("Rating cards advances the deck and builds the completion summary")
    func ratingAdvancesAndCompletesDeck() {
        let session = FlashcardSession(cards: cards)

        session.flip()
        #expect(session.isShowingAnswer)

        session.rate(.known)
        #expect(session.currentCard?.id == "two")
        #expect(!session.isShowingAnswer)
        #expect(session.knownCount == 1)

        session.rate(.learning)
        session.rate(.known)

        #expect(session.isComplete)
        #expect(session.knownCount == 2)
        #expect(session.learningCount == 1)
        #expect(session.completionPercentage == 67)
        #expect(session.progress == 1)
    }

    @Test("A learning card returns only after the configured card gap")
    func learningCardsAreRequeuedAfterGap() {
        let extendedCards = cards + [
            Flashcard(id: "four", prompt: "Fourth?", answer: "Fourth answer", topic: "Chapter 4"),
            Flashcard(id: "five", prompt: "Fifth?", answer: "Fifth answer", topic: "Chapter 5")
        ]
        let session = FlashcardSession(cards: extendedCards)

        session.rate(.learning)

        #expect(session.cards.map(\.id) == ["one", "two", "three", "four", "one", "five"])
        #expect(session.currentCard?.id == "two")

        session.rate(.known)
        session.rate(.known)
        #expect(session.currentCard?.id == "four")
        session.rate(.known)
        #expect(session.currentCard?.id == "one")
    }

    @Test("Known cards are remembered and learning cards become due after ten minutes")
    func persistentReviewScheduling() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let issues = PersistenceIssueCenter()
        let memory = FlashcardMemory(store: InMemoryFlashcardMemoryStore(), issues: issues)
        let catalog = FlashcardCatalog(cards: cards)

        memory.record(.known, for: cards[0], at: start)
        memory.record(.learning, for: cards[1], at: start)

        #expect(!memory.isAvailable(cards[0], at: start.addingTimeInterval(86_400)))
        #expect(!memory.isDue(cards[1], at: start.addingTimeInterval(599)))
        #expect(memory.isDue(cards[1], at: start.addingTimeInterval(600)))
        #expect(catalog.cards(for: .due, memory: memory, at: start.addingTimeInterval(600)).map(\.id) == ["two"])
        let summary = catalog.progressSummary(memory: memory)
        #expect(summary.totalAvailable == 3)
        #expect(summary.mastered == 1)
        #expect(summary.learning == 1)
        #expect(summary.totalReviews == 2)
        #expect(summary.masteryPercentage == 33)
        #expect(catalog.revisedCount(for: .newCards, memory: memory) == 2)
    }

    @Test("Guide cards are grouped into every chapter and a dates deck")
    func catalogBuildsChapterAndDateDecks() {
        let guideCards = (1...5).map { chapter in
            Flashcard(
                id: "chapter-\(chapter)",
                prompt: "Question \(chapter)?",
                answer: "Answer \(chapter)",
                topic: "Chapter \(chapter)",
                chapter: chapter,
                year: chapter == 3 ? "1215" : nil
            )
        }
        let issues = PersistenceIssueCenter()
        let memory = FlashcardMemory(store: InMemoryFlashcardMemoryStore(), issues: issues)
        let catalog = FlashcardCatalog(cards: guideCards)

        #expect(catalog.chapterNumbers == [1, 2, 3, 4, 5])
        #expect(FlashcardDeck.chapter(1).title == "Chapter 1: The values and principles of the UK")
        #expect(FlashcardDeck.chapter(2).title == "Chapter 2: What is the UK?")
        #expect(FlashcardDeck.chapter(3).title == "Chapter 3: A long and illustrious history")
        #expect(FlashcardDeck.chapter(4).title == "Chapter 4: A modern, thriving society")
        #expect(FlashcardDeck.chapter(5).title == "Chapter 5: The UK Government, the law and your role")
        for chapter in 1...5 {
            #expect(catalog.cards(for: .chapter(chapter), memory: memory, at: .distantPast).count == 1)
        }
        #expect(catalog.cards(for: .dates, memory: memory, at: .distantPast).map(\.id) == ["chapter-3"])

        memory.record(.known, for: guideCards[0], at: .distantPast)
        #expect(catalog.revisedCount(for: .chapter(1), memory: memory) == 1)
        #expect(catalog.revisedCount(for: .chapter(2), memory: memory) == 0)
    }

    @Test("Custom cards are saved into the selected deck")
    func customCardCreation() {
        let issues = PersistenceIssueCenter()
        let memory = FlashcardMemory(store: InMemoryFlashcardMemoryStore(), issues: issues)
        let catalog = FlashcardCatalog(cards: cards)

        memory.createCard(prompt: "When was Magna Carta agreed?", answer: "1215", chapter: 3, isDateCard: true)

        #expect(memory.customCards.count == 1)
        #expect(catalog.cards(for: .custom, memory: memory, at: .distantPast).count == 1)
        #expect(catalog.cards(for: .dates, memory: memory, at: .distantPast).contains { $0.prompt == "When was Magna Carta agreed?" })
    }
}

@MainActor
struct MatchGameStateTests {
    private let pairs = [
        MatchPair(id: "one", term: "One", definition: "First"),
        MatchPair(id: "two", term: "Two", definition: "Second")
    ]

    @Test("Correct matches complete the round and retain elapsed time")
    func correctMatchesFinishRound() {
        let start = Date(timeIntervalSince1970: 1_000)
        var game = MatchGameState(pairs: pairs, shuffleCards: false)

        game.start(at: start)
        game.select(cardID: "one-term", at: start.addingTimeInterval(1))
        game.select(cardID: "one-definition", at: start.addingTimeInterval(2))
        game.select(cardID: "two-term", at: start.addingTimeInterval(3))
        game.select(cardID: "two-definition", at: start.addingTimeInterval(4))

        #expect(game.phase == .finished)
        #expect(game.matchedCount == 2)
        #expect(game.finalTime == 4)
    }

    @Test("Every wrong match adds a three-second penalty")
    func wrongMatchAddsPenalty() {
        let start = Date(timeIntervalSince1970: 1_000)
        var game = MatchGameState(pairs: pairs, shuffleCards: false)

        game.start(at: start)
        game.select(cardID: "one-term", at: start)
        game.select(cardID: "two-definition", at: start.addingTimeInterval(2))

        #expect(game.mistakeCount == 1)
        #expect(game.penaltyTime == 3)
        #expect(game.elapsedTime(at: start.addingTimeInterval(2)) == 5)
        #expect(game.incorrectCardIDs == ["one-term", "two-definition"])
    }

    @Test("A matched card cannot be selected again")
    func matchedCardsAreIgnored() {
        var game = MatchGameState(pairs: pairs, shuffleCards: false)
        game.start()
        game.select(cardID: "one-term")
        game.select(cardID: "one-definition")
        game.select(cardID: "one-term")

        #expect(game.selectedCardID == nil)
        #expect(game.matchedCount == 1)
    }

    @Test("Dropping a card onto its match resolves the pair")
    func droppedCardsCanMatch() {
        var game = MatchGameState(pairs: pairs, shuffleCards: false)
        game.start()

        #expect(game.matchedCount == 0)
        #expect(game.incorrectCardIDs.isEmpty)

        game.match(cardID: "one-term", with: "one-definition")

        #expect(game.matchedCount == 1)
        #expect(game.mistakeCount == 0)
        #expect(game.incorrectCardIDs.isEmpty)
    }

    @Test("Dropping onto a wrong card reveals feedback and adds a penalty")
    func droppedCardsCanBeIncorrect() {
        var game = MatchGameState(pairs: pairs, shuffleCards: false)
        game.start()

        game.match(cardID: "one-term", with: "two-definition")

        #expect(game.matchedCount == 0)
        #expect(game.mistakeCount == 1)
        #expect(game.penaltyTime == 3)
        #expect(game.incorrectCardIDs == ["one-term", "two-definition"])
    }
}

@MainActor
struct StudyStatisticsTests {
    @Test("Flashcard statistics count new reviews and rating changes")
    func flashcardStatisticsTrackReviews() throws {
        let defaults = try #require(UserDefaults(suiteName: "StudyStatisticsTests.flashcards"))
        defaults.removePersistentDomain(forName: "StudyStatisticsTests.flashcards")

        StudyStatistics.recordFlashcardChanges(
            from: [:],
            to: ["one": .known, "two": .learning],
            defaults: defaults
        )
        StudyStatistics.recordFlashcardChanges(
            from: ["one": .known, "two": .learning],
            to: ["one": .known, "two": .known],
            defaults: defaults
        )

        #expect(defaults.integer(forKey: StudyStatistics.flashcardsReviewedKey) == 2)
        #expect(defaults.integer(forKey: StudyStatistics.flashcardsKnownKey) == 2)
    }

    @Test("Match statistics retain the fastest time and count every round")
    func matchStatisticsTrackBestTime() throws {
        let defaults = try #require(UserDefaults(suiteName: "StudyStatisticsTests.match"))
        defaults.removePersistentDomain(forName: "StudyStatisticsTests.match")

        StudyStatistics.recordMatchRound(time: 24.8, defaults: defaults)
        StudyStatistics.recordMatchRound(time: 28.1, defaults: defaults)
        StudyStatistics.recordMatchRound(time: 19.4, defaults: defaults)

        #expect(defaults.integer(forKey: StudyStatistics.matchRoundsKey) == 3)
        #expect(defaults.double(forKey: StudyStatistics.matchBestTimeKey) == 19.4)
    }
}

@MainActor
struct QuizConfigurationTests {
    private let customConfiguration = QuizConfiguration.custom(
        questionCount: 4,
        timeLimitSeconds: 90,
        passMarkCount: 3
    )

    @Test("A score immediately below the configured pass mark fails")
    func scoreBelowPassMarkFails() {
        var session = ExamSession(
            configuration: customConfiguration,
            questions: TestFixtures.questions(count: 4),
            startedAt: TestFixtures.startDate
        )

        for question in session.questions.prefix(2) {
            session.submit(answer: question.correctIndices, for: question)
        }

        #expect(session.score == 2)
        #expect(!session.passed)
    }

    @Test("A score equal to the configured pass mark passes")
    func scoreAtPassMarkPasses() {
        var session = ExamSession(
            configuration: customConfiguration,
            questions: TestFixtures.questions(count: 4),
            startedAt: TestFixtures.startDate
        )

        for question in session.questions.prefix(3) {
            session.submit(answer: question.correctIndices, for: question)
        }

        #expect(session.score == 3)
        #expect(session.passed)
    }

    @Test("Engine uses the supplied question count and duration")
    func engineUsesSuppliedConfiguration() {
        let engine = QuizEngine(
            configuration: customConfiguration,
            questionRepository: InMemoryQuestionRepository(TestFixtures.questions(count: 10)),
            clock: MutableQuizClock(now: TestFixtures.startDate)
        )

        #expect(engine.timeRemaining == 90)
        engine.startExam(testID: "custom-test")
        #expect(engine.session?.questions.count == 4)
        #expect(engine.session?.configuration == customConfiguration)
        #expect(engine.timeRemaining == 90)
        engine.stopTimer()
    }

    @Test("Configuration derives display labels from its rules")
    func derivedLabels() {
        #expect(customConfiguration.summaryLabel == "4 questions · 1 min")
        #expect(customConfiguration.passPercentage == 75)
    }
}

@MainActor
struct QuizAssistancePolicyTests {
    @Test("Exam help is locked until the current response is captured")
    func examHintPolicy() {
        #expect(!QuizMode.exam.allowsHints(hasAnsweredQuestion: false))
        #expect(QuizMode.exam.allowsHints(hasAnsweredQuestion: true))
        #expect(!QuizMode.exam.allowsBookAccess)
    }

    @Test("Non-exam modes retain hints and book access")
    func nonExamHelpPolicy() {
        for mode in [QuizMode.practice, .streak] {
            #expect(mode.allowsHints(hasAnsweredQuestion: false))
            #expect(mode.allowsBookAccess)
        }
    }

    @Test("Starting an exam records its mode separately from practice")
    func engineStartsExamMode() {
        let scheduler = ManualQuizScheduler()
        let engine = QuizEngine(
            configuration: .custom(questionCount: 1, timeLimitSeconds: 90, passMarkCount: 1),
            questionRepository: InMemoryQuestionRepository(TestFixtures.questions(count: 1)),
            clock: MutableQuizClock(now: TestFixtures.startDate),
            scheduler: scheduler
        )

        engine.startExam()
        #expect(engine.mode == .exam)
        #expect(!engine.hasAnsweredCurrentQuestion)

        engine.toggleChoice(0, isMultiSelect: false)
        scheduler.runNextDelayed()
        #expect(engine.hasAnsweredCurrentQuestion)
    }

    @Test("Section practice loads only matching questions and records practice evidence")
    func sectionPracticeTargetsConcepts() {
        let issues = PersistenceIssueCenter()
        let history = LearningEventHistory(store: InMemoryLearningEventStore(), issues: issues)
        let questions = [
            QuizQuestion(id: "a-1", question: "A?", choices: ["Right", "Wrong"], correctIndices: [0], isMultiSelect: false, year: "", category: 1, explanationLink: "", taxonomy: ContentTaxonomyTags(conceptIds: ["section-a"])),
            QuizQuestion(id: "b-1", question: "B?", choices: ["Right", "Wrong"], correctIndices: [0], isMultiSelect: false, year: "", category: 1, explanationLink: "", taxonomy: ContentTaxonomyTags(conceptIds: ["section-b"]))
        ]
        let engine = QuizEngine(questionRepository: InMemoryQuestionRepository(questions), learningEvents: history, clock: MutableQuizClock(now: TestFixtures.startDate), scheduler: ManualQuizScheduler())

        engine.startTargetedPractice(conceptIDs: ["section-a"], questionCount: 10)

        #expect(engine.mode == .practice)
        #expect(engine.session?.questions.map(\.id) == ["a-1"])
        engine.toggleChoice(0, isMultiSelect: false)
        engine.submitAndAdvance()
        #expect(history.questionAttempts.first?.source == .practiceQuestion)
        #expect(history.questionAttempts.first?.conceptWeights.map(\.conceptID) == ["section-a"])
        engine.stopTimer()
    }
}

@MainActor
struct ReaderTextSizeTests {
    @Test("Reader presets use the documented scale factors")
    func scaleFactors() {
        #expect(ReaderTextSize.small.scaleFactor == 0.90)
        #expect(ReaderTextSize.standard.scaleFactor == 1.00)
        #expect(ReaderTextSize.large.scaleFactor == 1.15)
    }

    @Test("Reader text size defaults to standard")
    func defaultValue() throws {
        let defaults = try makeDefaults(named: "default")

        #expect(ReaderTextSize.loadAndMigrate(defaults: defaults) == .standard)
    }

    @Test("Stored reader text size is restored and legacy state is cleaned up")
    func storedValue() throws {
        let defaults = try makeDefaults(named: "stored")
        defaults.set(ReaderTextSize.large.rawValue, forKey: ReaderTextSize.storageKey)
        defaults.set(-2.0, forKey: ReaderTextSize.legacyStorageKey)

        #expect(ReaderTextSize.loadAndMigrate(defaults: defaults) == .large)
        #expect(defaults.object(forKey: ReaderTextSize.legacyStorageKey) == nil)
    }

    @Test("Legacy reader adjustments migrate to the nearest preset")
    func legacyMigration() throws {
        let cases: [(adjustment: Double, expected: ReaderTextSize)] = [
            (-2, .small),
            (0, .standard),
            (4, .large),
        ]

        for testCase in cases {
            let defaults = try makeDefaults(named: "legacy-\(testCase.adjustment)")
            defaults.set(testCase.adjustment, forKey: ReaderTextSize.legacyStorageKey)

            let migratedValue = ReaderTextSize.loadAndMigrate(defaults: defaults)

            #expect(migratedValue == testCase.expected)
            #expect(defaults.string(forKey: ReaderTextSize.storageKey) == testCase.expected.rawValue)
            #expect(defaults.object(forKey: ReaderTextSize.legacyStorageKey) == nil)
        }
    }

    private func makeDefaults(named name: String) throws -> UserDefaults {
        let suiteName = "ReaderTextSizeTests.\(name)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

@MainActor
struct ProgressTests {
    @Test("Quiz progress is based on the current zero-based index")
    func quizProgressFraction() {
        var state = QuizState(configuration: .custom(questionCount: 4, timeLimitSeconds: 90, passMarkCount: 3))
        state.start(questions: TestFixtures.questions(count: 4), testID: nil, at: TestFixtures.startDate)
        #expect(state.progressFraction == 0)

        _ = state.toggleChoice(0)
        _ = state.submitCurrentAnswer()
        _ = state.advance(at: TestFixtures.startDate)
        _ = state.toggleChoice(0)
        _ = state.submitCurrentAnswer()
        _ = state.advance(at: TestFixtures.startDate)
        #expect(state.phase == .question(index: 2))
        #expect(state.progressFraction == 0.5)
    }

    @Test("Reading progress clamps scroll calculations")
    func readingProgressCalculation() {
        let progress = ReadingProgress(chapterID: "chapter_01", lastReadDate: TestFixtures.startDate)

        progress.updateProgress(
            scrollOffset: -50,
            contentHeight: 1_000,
            viewportHeight: 200,
            at: TestFixtures.laterDate
        )
        #expect(progress.progress == 0)

        progress.updateProgress(
            scrollOffset: 400,
            contentHeight: 1_000,
            viewportHeight: 200,
            at: TestFixtures.laterDate
        )
        #expect(progress.progress == 0.5)

        progress.updateProgress(
            scrollOffset: 900,
            contentHeight: 1_000,
            viewportHeight: 200,
            at: TestFixtures.laterDate
        )
        #expect(progress.progress == 1)
        #expect(progress.lastReadDate == TestFixtures.laterDate)
    }

    @Test("Overall completion averages deterministic chapter progress")
    func overallCompletion() throws {
        let store = InMemoryReadingProgressStore(records: [
            ReadingProgressSnapshot(chapterID: "chapter_01", progress: 0.25, lastReadDate: TestFixtures.startDate),
            ReadingProgressSnapshot(chapterID: "chapter_02", progress: 0.75, lastReadDate: TestFixtures.laterDate)
        ])
        let records = try store.fetchAll()
        #expect(records.reduce(0) { $0 + $1.progress } / 4 == 0.25)
    }

    @Test("Reading analytics require meaningful activity")
    func readingAnalyticsRequireActivity() {
        let untouched = ReadingProgressSnapshot(chapterID: "chapter_01")
        let scrolled = ReadingProgressSnapshot(chapterID: "chapter_01", scrollOffset: 12)
        let timed = ReadingProgressSnapshot(chapterID: "chapter_01", totalReadingTime: 3)

        #expect(!untouched.hasReadingActivity)
        #expect(scrolled.hasReadingActivity)
        #expect(timed.hasReadingActivity)
    }
}

struct MockExamInstructionsTests {
    @Test("Instructions are limited to the first three mock exam starts")
    func firstThreeMockExams() {
        let practiceAttempt = attempt(testID: "test-1")
        let firstTwoMockAttempts = [attempt(), attempt()]
        let firstThreeMockAttempts = firstTwoMockAttempts + [attempt()]

        #expect([practiceAttempt].shouldShowMockExamInstructions(presentationCount: 0))
        #expect(([practiceAttempt] + firstTwoMockAttempts).shouldShowMockExamInstructions(presentationCount: 0))
        #expect(!([practiceAttempt] + firstThreeMockAttempts).shouldShowMockExamInstructions(presentationCount: 0))
        #expect(![practiceAttempt].shouldShowMockExamInstructions(presentationCount: 3))
        #expect([practiceAttempt].nextMockExamInstructionPresentationCount(currentCount: 2) == 3)
    }

    private func attempt(testID: String? = nil) -> ExamAttemptSnapshot {
        ExamAttemptSnapshot(id: UUID(), attemptDate: Date(), score: 18, totalQuestions: 24, passed: true, elapsedSeconds: 1_200, didTimeOut: false, testID: testID)
    }
}

@MainActor
struct ExamCompletionRegressionTests {
    @Test("Completing the same exam twice persists one attempt")
    func duplicateCompletionPersistsOnce() {
        let store = RecordingAttemptStore()
        let clock = MutableQuizClock(now: TestFixtures.startDate)
        let scheduler = ManualQuizScheduler()
        let engine = QuizEngine(
            configuration: .custom(questionCount: 2, timeLimitSeconds: 90, passMarkCount: 1),
            questionRepository: InMemoryQuestionRepository(TestFixtures.questions(count: 2)),
            attemptStore: store,
            clock: clock,
            scheduler: scheduler
        )
        engine.startExam(testID: "test-1")
        clock.now = TestFixtures.laterDate

        engine.finishExam()
        engine.finishExam()

        #expect(store.saved.count == 1)
        #expect(store.saved.first?.attemptDate == TestFixtures.laterDate)
        #expect(store.saved.first?.elapsedSeconds == 300)
        #expect(store.saved.first?.testID == "test-1")
    }

    @Test("Timeout completes and persists exactly once")
    func timeoutPersistsOnce() {
        let store = RecordingAttemptStore()
        let clock = MutableQuizClock(now: TestFixtures.startDate)
        let scheduler = ManualQuizScheduler()
        let engine = QuizEngine(
            configuration: .custom(questionCount: 1, timeLimitSeconds: 1, passMarkCount: 1),
            questionRepository: InMemoryQuestionRepository(TestFixtures.questions(count: 1)),
            attemptStore: store,
            clock: clock,
            scheduler: scheduler
        )

        engine.startExam(testID: "timeout")
        clock.now = TestFixtures.laterDate
        scheduler.fireRepeating()
        engine.finishExam()

        #expect(engine.phase == .results)
        #expect(engine.didTimeOut)
        #expect(store.saved.count == 1)
        #expect(store.saved.first?.didTimeOut == true)
    }

    @Test("Delayed submission and advancement are controlled by the scheduler")
    func delayedTransitionsAreControllable() {
        let store = RecordingAttemptStore()
        let scheduler = ManualQuizScheduler()
        let engine = QuizEngine(
            configuration: .custom(questionCount: 1, timeLimitSeconds: 90, passMarkCount: 1),
            questionRepository: InMemoryQuestionRepository(TestFixtures.questions(count: 1)),
            attemptStore: store,
            clock: MutableQuizClock(now: TestFixtures.startDate),
            scheduler: scheduler
        )

        engine.startExam()
        engine.toggleChoice(0, isMultiSelect: false)
        #expect(!engine.hasSubmittedAnswer)

        scheduler.runNextDelayed()
        #expect(engine.hasSubmittedAnswer)
        #expect(engine.phase == .question(index: 0))

        scheduler.runNextDelayed()
        #expect(engine.phase == .results)
        #expect(store.saved.count == 1)
    }
}

@MainActor
struct QuizStateMachineTests {
    @Test("State transitions do not require UI, timers, or persistence")
    func pureTransitions() {
        var state = QuizState(configuration: .custom(questionCount: 2, timeLimitSeconds: 2, passMarkCount: 1))
        let questions = TestFixtures.questions(count: 2)

        state.start(questions: questions, testID: "pure", at: TestFixtures.startDate)
        #expect(state.phase == .question(index: 0))
        #expect(state.toggleChoice(0) == .submitAfter(0.3))
        #expect(state.submitCurrentAnswer() == .advanceAfter(2))
        #expect(state.advance(at: TestFixtures.startDate) == .none)
        #expect(state.phase == .question(index: 1))

        #expect(state.tick(at: TestFixtures.laterDate) == .none)
        let completion = state.tick(at: TestFixtures.laterDate)
        guard case .completed(let exam) = completion else {
            Issue.record("Expected timeout completion")
            return
        }
        #expect(exam.didTimeOut)
        #expect(state.phase == .results)
        #expect(state.finish(at: TestFixtures.laterDate, timedOut: true) == .none)
    }
}

@MainActor
struct StreakModeTests {
    @Test("A correct answer extends the streak and a wrong answer ends it")
    func streakStateTransitions() {
        var state = QuizState(configuration: .custom(questionCount: 2, timeLimitSeconds: 90, passMarkCount: 1))
        state.start(questions: TestFixtures.questions(count: 2), testID: nil, mode: .streak, at: TestFixtures.startDate)

        _ = state.toggleChoice(0)
        #expect(state.submitCurrentAnswer() == .advanceAfter(2))
        #expect(state.advance(at: TestFixtures.startDate) == .none)
        #expect(state.phase == .question(index: 1))
        #expect(state.session?.score == 1)

        _ = state.toggleChoice(1)
        #expect(state.submitCurrentAnswer() == .endStreakAfter(1.5))
        #expect(state.endStreak(at: TestFixtures.laterDate) == .streakEnded(1))
        #expect(state.phase == .streakResult)
        #expect(state.session?.finishedAt == TestFixtures.laterDate)
    }

    @Test("Streak mode uses every available question and does not run the exam timer")
    func streakLoadsAllQuestionsWithoutTimer() throws {
        let suiteName = "StreakModeTests.allQuestions"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let scheduler = ManualQuizScheduler()
        let engine = QuizEngine(
            configuration: .custom(questionCount: 1, timeLimitSeconds: 90, passMarkCount: 1),
            questionRepository: InMemoryQuestionRepository(TestFixtures.questions(count: 3)),
            clock: MutableQuizClock(now: TestFixtures.startDate),
            scheduler: scheduler,
            statisticsDefaults: defaults
        )

        engine.startStreak()
        #expect(engine.mode == .streak)
        #expect(engine.totalQuestions == 3)
        scheduler.fireRepeating()
        #expect(engine.timeRemaining == 90)

        engine.toggleChoice(0, isMultiSelect: false)
        scheduler.runNextDelayed()
        #expect(engine.bestStreak == 1)
        #expect(defaults.integer(forKey: StudyStatistics.longestStreakKey) == 1)
        scheduler.runNextDelayed()
        engine.toggleChoice(1, isMultiSelect: false)
        scheduler.runNextDelayed()
        scheduler.runNextDelayed()

        #expect(engine.phase == .streakResult)
        #expect(engine.currentStreak == 1)
        #expect(engine.bestStreak == 1)
        #expect(defaults.integer(forKey: StudyStatistics.longestStreakKey) == 1)

        engine.startStreak()
        #expect(engine.currentStreak == 0)
        #expect(engine.bestStreak == 1)
    }

    @Test("A shorter run never replaces the longest streak")
    func longestStreakOnlyIncreases() throws {
        let suiteName = "StreakModeTests.personalBest"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        #expect(StudyStatistics.recordStreak(4, defaults: defaults) == 4)
        #expect(StudyStatistics.recordStreak(2, defaults: defaults) == 4)
        #expect(StudyStatistics.longestStreak(defaults: defaults) == 4)
    }
}

@MainActor
struct ContentRepositoryTests {
    @Test("In-memory repositories replace production content without feature changes")
    func inMemoryRepositoriesSupplyContent() throws {
        let questions = TestFixtures.questions(count: 3)
        let chapter = TestFixtures.searchChapter

        let selected = try InMemoryQuestionRepository(questions)
            .questions(count: 2, seed: "fixture")
        let chapters = try InMemoryHandbookRepository([chapter]).document().chapters

        #expect(selected.count == 2)
        #expect(Set(selected.map(\.id)).isSubset(of: Set(questions.map(\.id))))
        #expect(chapters.map(\.id) == [chapter.id])
    }

    @Test("Missing bundle resources produce explicit typed errors")
    func missingBundleResourcesThrow() {
        let questions = BundleQuestionRepository(resourceName: "missing-questions-fixture")
        let handbook = BundleHandbookRepository(resourceName: "missing-handbook-fixture")

        #expect(throws: ContentRepositoryError.resourceNotFound("missing-questions-fixture.json")) {
            try questions.questions(count: 1, seed: nil)
        }
        #expect(throws: ContentRepositoryError.resourceNotFound("missing-handbook-fixture.json")) {
            try handbook.document()
        }
    }

    @Test("Question loading failures are surfaced by the quiz engine")
    func quizEngineSurfacesRepositoryFailure() {
        let engine = QuizEngine(
            questionRepository: InMemoryQuestionRepository([]),
            clock: MutableQuizClock(now: TestFixtures.startDate),
            scheduler: ManualQuizScheduler()
        )

        engine.startExam()

        #expect(engine.phase == .lobby)
        #expect(engine.contentError == .emptyContent("in-memory questions"))
    }

    @Test("Handbook loading failures are retained for retryable UI state")
    func handbookCatalogSurfacesRepositoryFailure() {
        let catalog = HandbookCatalog(repository: InMemoryHandbookRepository([]))

        #expect(catalog.chapters.isEmpty)
        #expect(catalog.error == .emptyContent("in-memory handbook"))
        catalog.reload()
        #expect(catalog.error == .emptyContent("in-memory handbook"))
    }

    @Test("Production bundle repositories decode packaged content")
    func bundleRepositoriesLoadPackagedContent() throws {
        let questions = try BundleQuestionRepository().questions(count: 3, seed: "bundle-test")
        let document = try BundleHandbookRepository().document()
        let chapters = document.chapters

        #expect(questions.count == 3)
        #expect(!chapters.isEmpty)
        #expect(!chapters[0].sections.isEmpty)
        #expect(document.contentVersion > 0)
        #expect(document.validBlockIDs.count == Set(document.validBlockIDs).count)
    }

    @Test("Stable block IDs keep highlights attached after reordering")
    func blockReorderingPreservesHighlightIdentity() throws {
        let highlight = HighlightSnapshot(chapterID: "chapter_01", sectionID: "section_01", blockID: "block_a", textPreview: "A")
        let store = InMemoryHighlightStore(records: [highlight])
        let issues = PersistenceIssueCenter()
        let library = HighlightLibrary(store: store, issues: issues)
        let reordered = [ContentBlock(id: "block_b", content: .paragraph("B")), ContentBlock(id: "block_a", content: .paragraph("A"))]

        #expect(library.highlights.first?.blockID == reordered[1].id)
        #expect(library.highlights.first?.blockID != reordered[0].id)
    }

    @Test("Multiple ranged highlights can coexist in one block")
    func multipleHighlightsPerBlock() {
        let store = InMemoryHighlightStore()
        let library = HighlightLibrary(store: store, issues: PersistenceIssueCenter())
        let first = HighlightSnapshot(
            chapterID: "chapter_01",
            sectionID: "section_01",
            blockID: "block_a",
            textPreview: "First",
            rangeLocation: 0,
            rangeLength: 5
        )
        let second = HighlightSnapshot(
            chapterID: "chapter_01",
            sectionID: "section_01",
            blockID: "block_a",
            color: .blue,
            textPreview: "Second",
            rangeLocation: 12,
            rangeLength: 6
        )

        library.upsert(first)
        library.upsert(second)

        #expect(library.highlights.count == 2)
        #expect(library.highlights.contains { $0.id == first.id && $0.selectedRange == first.selectedRange })
        #expect(library.highlights.contains { $0.id == second.id && $0.selectedRange == second.selectedRange })
    }

    @Test("Content migration rewrites renamed IDs and removes orphaned highlights")
    func contentIdentityMigrationPolicy() throws {
        let renamed = HighlightSnapshot(chapterID: "chapter_42", sectionID: "origins", blockID: "legacy_block", textPreview: "Magna", contentVersion: 1, rangeLocation: 2, rangeLength: 5)
        let removed = HighlightSnapshot(chapterID: "chapter_42", sectionID: "origins", blockID: "removed_block", textPreview: "Removed", contentVersion: 1)
        let store = InMemoryHighlightStore(records: [renamed, removed])
        let library = HighlightLibrary(store: store, issues: PersistenceIssueCenter())
        let document = HandbookDocument(
            contentVersion: 2,
            identityMigrations: ContentIdentityMigrations(
                renamedChapterIDs: [:],
                renamedSectionIDs: [:],
                renamedBlockIDs: ["legacy_block": "origins_block_001"],
                removedBlockIDs: ["removed_block"]
            ),
            chapters: [TestFixtures.searchChapter]
        )

        library.reconcile(document: document)

        #expect(library.highlights.count == 1)
        #expect(library.highlights.first?.blockID == "origins_block_001")
        #expect(library.highlights.first?.contentVersion == 2)
        #expect(library.highlights.first?.selectedRange == NSRange(location: 2, length: 5))
    }
}

@MainActor
struct QuestionJSONDecodingTests {
    @Test("Valid question JSON decodes and maps multi-select answers")
    func validJSON() throws {
        let data = Data(TestFixtures.validQuestionJSON.utf8)
        let decoded = try JSONDecoder().decode(RawQuestionsFile.self, from: data)
        let question = try #require(decoded.data.first.map(QuizQuestion.init(from:)))

        #expect(question.id == "json-1")
        #expect(question.correctIndices == [0, 2])
        #expect(question.isMultiSelect)
        #expect(question.category == 3)
    }

    @Test("Malformed JSON throws")
    func invalidJSON() {
        let data = Data(#"{"data":[}"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RawQuestionsFile.self, from: data)
        }
    }

    @Test("Missing required question data throws")
    func missingData() {
        let data = Data(#"{"data":[{"question_id":"missing-fields"}]}"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RawQuestionsFile.self, from: data)
        }
    }
}

@MainActor
struct SearchTests {
    @Test("Search is case-insensitive and returns one result per section")
    func caseInsensitiveSectionSearch() throws {
        let chapter = TestFixtures.searchChapter
        let results = try HandbookSearchService.search(query: "mAgNa CaRtA", chapters: [chapter])

        #expect(results.count == 1)
        let result = try #require(results.first)
        #expect(result.chapter.id == chapter.id)
        #expect(result.sectionIndex == 0)
        #expect(result.snippet.lowercased().contains("magna carta"))
        #expect(result.matchRange.map { String(result.snippet[$0]).lowercased() } == "magna carta")
    }

    @Test("Search returns no result for an absent term")
    func absentSearchTerm() throws {
        let results = try HandbookSearchService.search(
            query: "parliament",
            chapters: [TestFixtures.searchChapter]
        )
        #expect(results.isEmpty)
    }

    @Test("Search builds Unicode-safe snippets")
    func unicodeSnippet() throws {
        let text = String(repeating: "Earlier context with history. ", count: 4) + "The café welcomes every citizen."
        let chapter = TestFixtures.chapter(blockID: "unicode_block", text: text)
        let result = try #require(HandbookSearchService.search(query: "CAFE", chapters: [chapter], maximumSnippetLength: 70).first)

        #expect(result.snippet.hasPrefix("..."))
        #expect(result.matchRange.map { String(result.snippet[$0]) } == "café")
    }

    @Test("Search result identity is stable and content-based")
    func stableResultIdentity() throws {
        let chapter = TestFixtures.searchChapter
        let first = try #require(HandbookSearchService.search(query: "magna carta", chapters: [chapter]).first)
        let second = try #require(HandbookSearchService.search(query: "MAGNA CARTA", chapters: [chapter]).first)

        #expect(first.id == "chapter_42/origins/origins_block_001")
        #expect(first.id == second.id)
        #expect(first.blockID == "origins_block_001")
    }

    @Test("Repository-backed search supports cancellation")
    func cancellation() async {
        let chapters = (0..<2_000).map { index in
            TestFixtures.chapter(blockID: "block_\(index)", text: "Content without the requested phrase \(index)")
        }
        let service = HandbookSearchService(repository: InMemoryHandbookRepository(chapters))
        let task = Task { try await service.search(query: "not present anywhere") }
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected the search task to be cancelled")
        } catch is CancellationError {
            // Expected.
        } catch {
            Issue.record("Expected CancellationError, received \(error)")
        }
    }

    @Test("Repository loading and searching run away from the main actor")
    func offMainActor() async throws {
        let document = InMemoryHandbookRepository([TestFixtures.searchChapter]).handbook
        let repository = ThreadCheckingHandbookRepository(document: document)
        let service = HandbookSearchService(repository: repository)

        _ = try await service.search(query: "Magna Carta")

        #expect(repository.wasCalled)
        #expect(!repository.wasCalledOnMainThread)
    }
}

@MainActor
struct AppCompositionTests {
    @Test("Test composition injects feature-scoped repositories, stores, clock, and scheduler")
    func testComposition() throws {
        let clock = MutableQuizClock(now: TestFixtures.startDate)
        let scheduler = ManualQuizScheduler()
        let dependencies = try AppDependencies.test(
            questions: TestFixtures.questions(count: 3),
            chapters: [TestFixtures.searchChapter],
            clock: clock,
            scheduler: scheduler
        )

        #expect(dependencies.quiz.clock.now == TestFixtures.startDate)
        #expect(dependencies.quiz.attempts === dependencies.tests.quiz.attempts)
        #expect(dependencies.handbook.catalog.chapters.map(\.contentID) == ["chapter_42"])
        #expect(dependencies.handbook.reader.revision != nil)
    }

    @Test("Preview composition uses independently constructed in-memory state")
    func previewComposition() throws {
        let dependencies = try AppDependencies.preview(
            questions: TestFixtures.questions(count: 2),
            chapters: [TestFixtures.searchChapter],
            progress: [ReadingProgressSnapshot(chapterID: "chapter_42", progress: 0.5)]
        )

        #expect(dependencies.handbook.progress.progress(for: "chapter_42")?.progress == 0.5)
        #expect(dependencies.quiz.attempts.attempts.isEmpty)
    }
}

@MainActor
private enum TestFixtures {
    static let startDate = Date(timeIntervalSince1970: 1_700_000_000)
    static let laterDate = Date(timeIntervalSince1970: 1_700_000_300)

    static func question(id: String, correctIndices: Set<Int> = [0]) -> QuizQuestion {
        QuizQuestion(
            id: id,
            question: "Question \(id)",
            choices: ["A", "B", "C"],
            correctIndices: correctIndices,
            isMultiSelect: correctIndices.count > 1,
            year: "2026",
            category: 1,
            explanationLink: "section-1"
        )
    }

    static func questions(count: Int) -> [QuizQuestion] {
        (0..<count).map { question(id: "q-\($0)") }
    }

    static func modelContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ExamAttempt.self,
            ReadingProgress.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    static let searchChapter = HandbookChapter(
        id: 42,
        contentID: "chapter_42",
        number: "Chapter 42",
        title: "Test History",
        pillLabels: ["Origins"],
        sections: [
            HandbookSection(
                id: "origins",
                title: "Origins",
                blocks: [
                    ContentBlock(id: "origins_block_001", content: .paragraph("The **Magna Carta** was agreed in 1215.")),
                    ContentBlock(id: "origins_block_002", content: .paragraph("A second Magna Carta mention stays within the same section."))
                ]
            )
        ]
    )

    static func chapter(blockID: String, text: String) -> HandbookChapter {
        HandbookChapter(
            id: 0,
            contentID: "chapter_\(blockID)",
            number: "Chapter",
            title: "Search Fixture",
            pillLabels: ["Fixture"],
            sections: [
                HandbookSection(
                    id: "section_\(blockID)",
                    title: "Fixture",
                    blocks: [ContentBlock(id: blockID, content: .paragraph(text))]
                )
            ]
        )
    }

    static let validQuestionJSON = #"""
    {
      "data": [{
        "question_id": "json-1",
        "book_section_id": "section-1",
        "category": "3",
        "question": "Choose two",
        "year": "2026",
        "choices": ["A", "B", "C"],
        "correct": ["0", "2"],
        "explanation": { "link": "section-1" }
      }]
    }
    """#
}

@MainActor
private final class RecordingAttemptStore: ExamAttemptStore {
    private(set) var saved: [CompletedExam] = []

    func fetchAll() throws -> [ExamAttemptSnapshot] { [] }

    func save(_ exam: CompletedExam) throws {
        saved.append(exam)
    }
}

private final class ThreadCheckingHandbookRepository: HandbookRepository, @unchecked Sendable {
    private let documentValue: HandbookDocument
    private let lock = NSLock()
    private var called = false
    private var calledOnMainThread = false

    init(document: HandbookDocument) { documentValue = document }

    nonisolated func document() throws -> HandbookDocument {
        lock.withLock {
            called = true
            calledOnMainThread = Thread.isMainThread
        }
        return documentValue
    }

    var wasCalled: Bool { lock.withLock { called } }
    var wasCalledOnMainThread: Bool { lock.withLock { calledOnMainThread } }
}

private final class MutableQuizClock: QuizClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

@MainActor
private final class ManualQuizScheduler: QuizScheduler {
    private final class ScheduledAction {
        var isCancelled = false
        let action: @MainActor () -> Void

        init(action: @escaping @MainActor () -> Void) {
            self.action = action
        }
    }

    private var delayed: [ScheduledAction] = []
    private var repeating: [ScheduledAction] = []

    func schedule(after delay: TimeInterval, action: @escaping @MainActor () -> Void) -> QuizCancellation {
        let scheduled = ScheduledAction(action: action)
        delayed.append(scheduled)
        return QuizCancellation { scheduled.isCancelled = true }
    }

    func scheduleRepeating(every interval: TimeInterval, action: @escaping @MainActor () -> Void) -> QuizCancellation {
        let scheduled = ScheduledAction(action: action)
        repeating.append(scheduled)
        return QuizCancellation { scheduled.isCancelled = true }
    }

    func runNextDelayed() {
        while !delayed.isEmpty {
            let scheduled = delayed.removeFirst()
            if !scheduled.isCancelled {
                scheduled.action()
                return
            }
        }
    }

    func fireRepeating() {
        repeating.filter { !$0.isCancelled }.forEach { $0.action() }
    }
}
