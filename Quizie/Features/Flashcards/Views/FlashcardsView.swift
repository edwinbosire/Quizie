import SwiftUI

struct FlashcardsView: View {
    let dependencies: FlashcardFeatureDependencies
    @State private var presentedSheet: FlashcardSheet?

    var body: some View {
        Group {
            if let contentError = dependencies.catalog.contentError {
                FlashcardUnavailableView(message: contentError)
            } else {
                landingPage
            }
        }
        .background(Color.hbBackground.ignoresSafeArea())
        .navigationTitle("Flashcards")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .create:
                CreateFlashcardView(memory: dependencies.memory, taxonomyTagger: dependencies.taxonomyTagger)
            }
        }
    }

    private var landingPage: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                FlashcardStatisticsCard(
                    summary: dependencies.catalog.progressSummary(memory: dependencies.memory)
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("STUDY")
                        .appFont(.caption.weight(.semibold))
                        .foregroundStyle(Color.hbTextMuted)

                    Button {
                        presentedSheet = .create
                    } label: {
                        FlashcardActionRow(
                            title: "Create new flashcards",
                            detail: "Add your own questions and answers",
                            icon: "plus.rectangle.on.rectangle",
                            accent: Color.hbAccent
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("flashcards.create")

                    NavigationLink(value: FlashcardDeck.newCards) {
                        FlashcardActionRow(
                            title: "Learn new flashcards",
                            detail: newCardsDetail,
                            icon: "sparkles.rectangle.stack",
                            accent: Color(hex: "#512E5F")
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(newCardCount == 0)
                    .opacity(newCardCount == 0 ? 0.55 : 1)

                    NavigationLink(value: FlashcardDeck.due) {
                        FlashcardActionRow(
                            title: "Practice upcoming flashcards",
                            detail: dueCardsDetail,
                            icon: "clock.arrow.circlepath",
                            accent: Color(hex: "#9B4A20")
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(dueCount == 0)
                    .opacity(dueCount == 0 ? 0.55 : 1)
                    .accessibilityIdentifier("flashcards.upcoming")
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("TRAIN BY CHAPTER")
                        .appFont(.caption.weight(.semibold))
                        .foregroundStyle(Color.hbTextMuted)

                    ForEach(dependencies.catalog.chapterNumbers, id: \.self) { chapter in
                        deckRow(for: .chapter(chapter), icon: "book.closed.fill", chapter: chapter)
                    }

                    deckRow(for: .dates, icon: "calendar", chapter: nil)

                    if !dependencies.memory.customCards.isEmpty {
                        deckRow(for: .custom, icon: "person.crop.rectangle.stack", chapter: nil)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 36)
        }
        .accessibilityIdentifier("flashcards.landing")
    }

    private func deckRow(for deck: FlashcardDeck, icon: String, chapter: Int?) -> some View {
        let total = dependencies.catalog.totalCount(for: deck, memory: dependencies.memory)
        let mastered = dependencies.catalog.masteredCount(for: deck, memory: dependencies.memory)
        let revised = dependencies.catalog.revisedCount(for: deck, memory: dependencies.memory)
        let available = dependencies.catalog.cards(
            for: deck,
            memory: dependencies.memory,
            at: dependencies.clock.now
        ).count
        let theme = chapter.map { ChapterTheme.forChapter(max(0, $0 - 1)) }

        return NavigationLink(value: deck) {
            if let chapter,
               let chapterName = FlashcardDeck.chapterName(for: chapter) {
                ChapterBrowseRow(
                    chapterNumber: "Chapter \(chapter)",
                    title: chapterName,
                    chapterIndex: max(0, chapter - 1),
                    detail: "\(total) flashcard\(total == 1 ? "" : "s") · \(revised) revised",
                    trailingSystemImage: available == 0 ? "checkmark.circle.fill" : "chevron.right"
                )
            } else {
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .appFont(.headline.weight(.semibold))
                        .foregroundStyle(theme?.accent ?? Color.hbAccent)
                        .frame(width: 42, height: 42)
                        .background(theme?.accentLight ?? Color.hbAccentLight)
                        .clipShape(RoundedRectangle(cornerRadius: HBRadius.sm))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(deck.title)
                            .appFont(.callout.weight(.semibold))
                            .foregroundStyle(Color.hbTextPrimary)

                        Text(available == 0 ? "Complete · \(mastered) mastered" : "\(available) ready · \(mastered) of \(total) mastered")
                            .appFont(.caption)
                            .foregroundStyle(Color.hbTextMuted)
                    }

                    Spacer()

                    Image(systemName: available == 0 ? "checkmark.circle.fill" : "chevron.right")
                        .appFont(.footnote.weight(.semibold))
                        .foregroundStyle(available == 0 ? Color(hex: "#145A32") : Color.hbTextMuted)
                }
                .padding(14)
                .background(Color.hbSurface)
                .clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
                .overlay {
                    RoundedRectangle(cornerRadius: HBRadius.md)
                        .stroke(Color.hbBorder, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(available == 0)
        .accessibilityIdentifier(deck.accessibilityIdentifier)
    }

    private var allCards: [Flashcard] {
        dependencies.catalog.allCards(memory: dependencies.memory)
    }

    private var newCardCount: Int {
        allCards.filter { dependencies.memory.review(for: $0.id) == nil }.count
    }

    private var dueCount: Int {
        allCards.filter { dependencies.memory.isDue($0, at: dependencies.clock.now) }.count
    }

    private var newCardsDetail: String {
        newCardCount == 0 ? "You’ve learned every available card" : "Start a focused set of up to \(min(newCardCount, FlashcardCatalog.newSessionLimit)) cards"
    }

    private var dueCardsDetail: String {
        dueCount == 0 ? "Nothing is due right now" : "\(dueCount) learning \(dueCount == 1 ? "card is" : "cards are") ready"
    }
}

extension View {
    func flashcardNavigationDestinations(
        dependencies: FlashcardFeatureDependencies
    ) -> some View {
        navigationDestination(for: FlashcardDeck.self) { deck in
            FlashcardPracticeView(
                title: deck.title,
                cards: dependencies.catalog.cards(
                    for: deck,
                    memory: dependencies.memory,
                    at: dependencies.clock.now
                ),
                memory: dependencies.memory,
                clock: dependencies.clock
            )
        }
    }
}

private extension FlashcardDeck {
    var accessibilityIdentifier: String {
        switch self {
        case .newCards: return "flashcards.deck.new"
        case .due: return "flashcards.deck.due"
        case .chapter(let number): return "flashcards.deck.chapter.\(number)"
        case .concept(let ids, _): return "flashcards.deck.concept.\(ids.first ?? "unknown")"
        case .dates: return "flashcards.deck.dates"
        case .custom: return "flashcards.deck.custom"
        }
    }
}

private enum FlashcardSheet: String, Identifiable {
    case create
    var id: String { rawValue }
}

private struct FlashcardStatisticsCard: View {
    let summary: FlashcardProgressSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("YOUR PROGRESS")
                        .appFont(.caption.weight(.semibold))
                        .foregroundStyle(Color.hbTextMuted)
                    Text(summary.reviewed == 0 ? "Ready to begin" : "\(summary.masteryPercentage)% mastered")
                        .appFont(.system(.title2, design: .serif, weight: .semibold))
                        .foregroundStyle(Color.hbTextPrimary)
                }

                Spacer()

                Image(systemName: "chart.line.uptrend.xyaxis")
                    .appFont(.title3.weight(.semibold))
                    .foregroundStyle(Color.hbAccent)
                    .frame(width: 46, height: 46)
                    .background(Color.hbAccentLight)
                    .clipShape(Circle())
            }

            HStack(spacing: 0) {
                statistic(value: summary.mastered, label: "MASTERED", color: Color(hex: "#145A32"))
                Divider().frame(height: 36)
                statistic(value: summary.learning, label: "LEARNING", color: Color(hex: "#9B4A20"))
                Divider().frame(height: 36)
                statistic(value: summary.totalReviews, label: "REVIEWS", color: Color.hbAccent)
            }
        }
        .padding(20)
        .background(Color.hbSurface)
        .clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: HBRadius.md)
                .stroke(Color.hbBorder, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 12, y: 5)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("flashcards.statistics")
    }

    private func statistic(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .appFont(.headline.weight(.semibold))
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label)
                .appFont(.caption2.weight(.semibold))
                .foregroundStyle(Color.hbTextMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct FlashcardActionRow: View {
    let title: String
    let detail: String
    let icon: String
    let accent: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .appFont(.headline.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 42, height: 42)
                .background(accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: HBRadius.sm))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .appFont(.callout.weight(.semibold))
                    .foregroundStyle(Color.hbTextPrimary)
                Text(detail)
                    .appFont(.caption)
                    .foregroundStyle(Color.hbTextMuted)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .appFont(.footnote.weight(.semibold))
                .foregroundStyle(Color.hbTextMuted)
        }
        .padding(14)
        .background(Color.hbSurface)
        .clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: HBRadius.md)
                .stroke(Color.hbBorder, lineWidth: 1)
        }
    }
}

private struct FlashcardPracticeView: View {
    @State private var session: FlashcardSession
    let title: String

    init(title: String, cards: [Flashcard], memory: FlashcardMemory, clock: any QuizClock) {
        self.title = title
        _session = State(initialValue: FlashcardSession(cards: cards, memory: memory, clock: clock))
    }

    var body: some View {
        Group {
            if session.cards.isEmpty {
                FlashcardUnavailableView(message: "There are no flashcards ready in this deck.")
            } else if session.isComplete {
                FlashcardCompletionView(session: session)
            } else {
                FlashcardStudyView(session: session)
            }
        }
        .background(Color.hbBackground.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onChange(of: session.ratings) { previous, current in
            StudyStatistics.recordFlashcardChanges(from: previous, to: current)
        }
    }
}

private struct FlashcardStudyView: View {
    let session: FlashcardSession

    var body: some View {
        VStack(spacing: 0) {
            progressHeader

            if let card = session.currentCard {
                FlashcardCardView(
                    card: card,
                    isShowingAnswer: session.isShowingAnswer,
                    onFlip: session.flip
                )
                .id(card.id)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }

            studyControls
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
        }
        .animation(.easeInOut(duration: 0.25), value: session.currentIndex)
        .accessibilityIdentifier("flashcards.study")
    }

    private var progressHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Label("\(session.learningCount)", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                    .foregroundStyle(Color(hex: "#9B4A20"))
                Spacer()
                Text(session.positionLabel)
                    .appFont(.callout.weight(.semibold))
                    .foregroundStyle(Color.hbTextSecondary)
                    .monospacedDigit()
                Spacer()
                Label("\(session.knownCount)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color(hex: "#145A32"))
            }
            .appFont(.footnote.weight(.semibold))

            ProgressView(value: session.progress)
                .tint(Color.hbAccent)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var studyControls: some View {
        if session.isShowingAnswer {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                ratingButton(
                    title: "Again",
                    icon: "arrow.counterclockwise",
                    foreground: Color(hex: "#8A431F"),
                    background: Color(hex: "#F5E6DA")
                ) { session.rate(.again) }

                ratingButton(
                    title: "Hard",
                    icon: "brain.head.profile",
                    foreground: Color(hex: "#8A6500"),
                    background: Color(hex: "#FFF1C7")
                ) { session.rate(.hard) }

                ratingButton(
                    title: "Good",
                    icon: "checkmark",
                    foreground: Color(hex: "#145A32"),
                    background: Color(hex: "#D5F5E3")
                ) { session.rate(.good) }

                ratingButton(
                    title: "Easy",
                    icon: "sparkles",
                    foreground: Color(hex: "#1B4F72"),
                    background: Color(hex: "#D6E8F5")
                ) { session.rate(.easy) }
            }
        } else {
            Button(action: session.flip) {
                Label("Tap to reveal answer", systemImage: "rectangle.on.rectangle.angled")
                    .appFont(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.hbAccent)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func ratingButton(
        title: String,
        icon: String,
        foreground: Color,
        background: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .appFont(.subheadline.weight(.semibold))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
        }
    }
}

private struct FlashcardCardView: View {
    let card: Flashcard
    let isShowingAnswer: Bool
    let onFlip: () -> Void

    var body: some View {
        ZStack {
            cardFace(title: "QUESTION", text: card.prompt)
                .opacity(isShowingAnswer ? 0 : 1)
                .accessibilityHidden(isShowingAnswer)

            cardFace(title: "ANSWER", text: card.answer)
                .opacity(isShowingAnswer ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .accessibilityHidden(!isShowingAnswer)
        }
        .rotation3DEffect(
            .degrees(isShowingAnswer ? 180 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.45
        )
        .animation(.spring(response: 0.48, dampingFraction: 0.82), value: isShowingAnswer)
        .contentShape(RoundedRectangle(cornerRadius: 24))
        .onTapGesture(perform: onFlip)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(isShowingAnswer ? "Answer: \(card.answer)" : "Question: \(card.prompt)")
        .accessibilityHint("Double tap to flip the card")
        .accessibilityIdentifier("flashcards.card")
    }

    private func cardFace(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(card.topic.uppercased())
                .appFont(.caption2.weight(.semibold))
                .foregroundStyle(Color.hbAccent)
                .padding(.vertical, 8)

            Spacer(minLength: 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(title)
                        .appFont(.caption.weight(.semibold))
                        .foregroundStyle(Color.hbTextMuted)

                    Text(text)
                        .appFont(.studyPrompt)
                        .foregroundStyle(Color.hbTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, minHeight: 260, alignment: .center)
            }
            .scrollIndicators(.hidden)

            Spacer(minLength: 16)

            Label(
                isShowingAnswer ? "Tap card to see the question" : "Tap card to reveal the answer",
                systemImage: "hand.tap"
            )
            .appFont(.footnote)
            .foregroundStyle(Color.hbTextMuted)
            .frame(maxWidth: .infinity)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.hbSurface)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.hbBorder, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 18, y: 8)
    }
}

private struct FlashcardCompletionView: View {
    @Environment(\.dismiss) private var dismiss
    let session: FlashcardSession

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .appFont(.largeTitle.weight(.semibold))
                        .foregroundStyle(Color.hbAccent)
                    Text("Practice complete")
                        .appFont(.system(.title, design: .serif, weight: .semibold))
                        .foregroundStyle(Color.hbTextPrimary)
                    Text("Cards you know are now mastered. Cards still in learning will return when they’re due.")
                        .appFont(.callout)
                        .foregroundStyle(Color.hbTextMuted)
                        .multilineTextAlignment(.center)
                }

                ZStack {
                    Circle().stroke(Color.hbSurface2, lineWidth: 18)
                    Circle()
                        .trim(from: 0, to: CGFloat(session.completionPercentage) / 100)
                        .stroke(Color.hbAccent, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text("\(session.completionPercentage)%")
                            .appFont(.system(.title, design: .serif, weight: .semibold))
                            .foregroundStyle(Color.hbTextPrimary)
                        Text("MASTERED")
                            .appFont(.caption2.weight(.semibold))
                            .foregroundStyle(Color.hbTextMuted)
                    }
                }
                .frame(width: 190, height: 190)

                VStack(spacing: 12) {
                    resultRow(title: "Know it", value: session.knownCount, color: Color(hex: "#D5F5E3"), icon: "checkmark.circle.fill")
                    resultRow(title: "Still learning", value: session.learningCount, color: Color(hex: "#F5E6DA"), icon: "arrow.trianglehead.2.clockwise.rotate.90")
                }

                Button(action: dismiss.callAsFunction) {
                    Text("Back to flashcards")
                        .appFont(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.hbAccent)
                        .clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
                }
            }
            .padding(24)
        }
        .accessibilityIdentifier("flashcards.completion")
    }

    private func resultRow(title: String, value: Int, color: Color, icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Text("\(value)").monospacedDigit()
        }
        .appFont(.callout.weight(.semibold))
        .foregroundStyle(Color.hbTextSecondary)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
    }
}

private struct CreateFlashcardView: View {
    @Environment(\.dismiss) private var dismiss
    let memory: FlashcardMemory
    let taxonomyTagger: TaxonomyTagResolver
    @State private var prompt = ""
    @State private var answer = ""
    @State private var category = CreateFlashcardCategory.custom

    var body: some View {
        NavigationStack {
            Form {
                Section("Flashcard") {
                    TextField("Question", text: $prompt, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Answer", text: $answer, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(CreateFlashcardCategory.allCases) { value in
                            Text(value.title).tag(value)
                        }
                    }
                }
            }
            .navigationTitle("New flashcard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let taxonomy = taxonomyTagger.tags(for: "\(prompt) \(answer)", chapter: category.chapter)
                        memory.createCard(
                            prompt: prompt,
                            answer: answer,
                            chapter: category.chapter,
                            isDateCard: category == .dates,
                            taxonomy: taxonomy
                        )
                        dismiss()
                    }
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private enum CreateFlashcardCategory: String, CaseIterable, Identifiable {
    case custom
    case chapter1
    case chapter2
    case chapter3
    case chapter4
    case chapter5
    case dates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .custom: return "My flashcards"
        case .chapter1: return "Chapter 1"
        case .chapter2: return "Chapter 2"
        case .chapter3: return "Chapter 3"
        case .chapter4: return "Chapter 4"
        case .chapter5: return "Chapter 5"
        case .dates: return "Important dates"
        }
    }

    var chapter: Int? {
        switch self {
        case .chapter1: return 1
        case .chapter2: return 2
        case .chapter3: return 3
        case .chapter4: return 4
        case .chapter5: return 5
        case .custom, .dates: return nil
        }
    }
}

private struct FlashcardUnavailableView: View {
    let message: String

    var body: some View {
        ContentUnavailableView(
            "Flashcards Unavailable",
            systemImage: "rectangle.stack.badge.exclamationmark",
            description: Text(message)
        )
    }
}

#Preview("Flashcards Landing") {
    let issues = PersistenceIssueCenter()
    let memory = FlashcardMemory(store: InMemoryFlashcardMemoryStore(), issues: issues)
    let dependencies = FlashcardFeatureDependencies(
        catalog: FlashcardCatalog(cards: [
            Flashcard(id: "1", prompt: "Which countries make up Great Britain?", answer: "England, Scotland and Wales", topic: "Chapter 2", chapter: 2),
            Flashcard(id: "2", prompt: "When was Magna Carta agreed?", answer: "1215", topic: "Chapter 3", chapter: 3, year: "1215")
        ]),
        memory: memory,
        clock: SystemQuizClock(),
        aiInference: MockInferenceService()
    )

    return NavigationStack {
        FlashcardsView(dependencies: dependencies)
            .flashcardNavigationDestinations(dependencies: dependencies)
    }
}
