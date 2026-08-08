import SwiftUI

struct FlashcardsView: View {
    @State private var session: FlashcardSession

    init(dependencies: QuizFeatureDependencies) {
        _session = State(initialValue: FlashcardSession(repository: dependencies.questions))
    }

    init(cards: [Flashcard]) {
        _session = State(initialValue: FlashcardSession(cards: cards))
    }

    var body: some View {
        Group {
            if let contentError = session.contentError {
                FlashcardUnavailableView(message: contentError)
            } else if session.cards.isEmpty {
                FlashcardUnavailableView(message: "There are no flashcards in this deck yet.")
            } else if session.isComplete {
                FlashcardCompletionView(session: session)
            } else {
                FlashcardStudyView(session: session)
            }
        }
        .background(Color.hbBackground.ignoresSafeArea())
        .navigationTitle("Flashcards")
        .navigationBarTitleDisplayMode(.inline)
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
                FlashcardView(
                    card: card,
                    isShowingAnswer: session.isShowingAnswer,
                    isStarred: session.isCurrentCardStarred,
                    onFlip: session.flip,
                    onToggleStar: session.toggleStar
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
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.hbTextSecondary)
                    .monospacedDigit()

                Spacer()

                Label("\(session.knownCount)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color(hex: "#145A32"))
            }
            .font(.footnote.weight(.semibold))

            ProgressView(value: session.progress)
                .tint(Color.hbAccent)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var studyControls: some View {
        if session.isShowingAnswer {
            HStack(spacing: 12) {
                ratingButton(
                    title: "Still learning",
                    icon: "arrow.trianglehead.2.clockwise.rotate.90",
                    foreground: Color(hex: "#8A431F"),
                    background: Color(hex: "#F5E6DA")
                ) {
                    session.rate(.learning)
                }

                ratingButton(
                    title: "Know it",
                    icon: "checkmark",
                    foreground: Color(hex: "#145A32"),
                    background: Color(hex: "#D5F5E3")
                ) {
                    session.rate(.known)
                }
            }
        } else {
            HStack {
                Button(action: session.goBack) {
                    Image(systemName: "arrow.left")
                        .frame(width: 44, height: 44)
                }
                .disabled(!session.canGoBack)
                .foregroundStyle(session.canGoBack ? Color.hbAccent : Color.hbTextMuted.opacity(0.35))
                .accessibilityLabel("Previous card")

                Spacer()

                Button(action: session.flip) {
                    Label("Tap to reveal answer", systemImage: "rectangle.on.rectangle.angled")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.hbAccent)
                }

                Spacer()

                Color.clear
                    .frame(width: 44, height: 44)
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
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
        }
    }
}

private struct FlashcardView: View {
    let card: Flashcard
    let isShowingAnswer: Bool
    let isStarred: Bool
    let onFlip: () -> Void
    let onToggleStar: () -> Void

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
            HStack {
                Text(card.topic.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.hbAccent)

                Spacer()

                Button(action: onToggleStar) {
                    Image(systemName: isStarred ? "star.fill" : "star")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(isStarred ? Color(hex: "#D99B16") : Color.hbTextMuted)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(isStarred ? "Remove from starred cards" : "Add to starred cards")
            }

            Spacer(minLength: 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.hbTextMuted)

                    Text(text)
                        .font(.system(.title2, design: .serif))
                        .foregroundStyle(Color.hbTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, minHeight: 250, alignment: .center)
            }
            .scrollIndicators(.hidden)

            Spacer(minLength: 16)

            Label(
                isShowingAnswer ? "Tap card to see the question" : "Tap card to reveal the answer",
                systemImage: "hand.tap"
            )
            .font(.footnote)
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
    let session: FlashcardSession

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(Color.hbAccent)

                    Text("Deck complete")
                        .font(.system(.title, design: .serif, weight: .semibold))
                        .foregroundStyle(Color.hbTextPrimary)

                    Text("Nice work. Keep the cards you missed in rotation until they feel easy.")
                        .font(.callout)
                        .foregroundStyle(Color.hbTextMuted)
                        .multilineTextAlignment(.center)
                }

                ZStack {
                    Circle()
                        .stroke(Color.hbSurface2, lineWidth: 18)

                    Circle()
                        .trim(from: 0, to: CGFloat(session.completionPercentage) / 100)
                        .stroke(Color.hbAccent, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text("\(session.completionPercentage)%")
                            .font(.system(.title, design: .serif, weight: .semibold))
                            .foregroundStyle(Color.hbTextPrimary)
                        Text("KNOWN")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.hbTextMuted)
                    }
                }
                .frame(width: 190, height: 190)

                VStack(spacing: 12) {
                    resultRow(
                        title: "Know it",
                        value: session.knownCount,
                        color: Color(hex: "#D5F5E3"),
                        icon: "checkmark.circle.fill"
                    )
                    resultRow(
                        title: "Still learning",
                        value: session.learningCount,
                        color: Color(hex: "#F5E6DA"),
                        icon: "arrow.trianglehead.2.clockwise.rotate.90"
                    )
                }

                VStack(spacing: 12) {
                    Button(action: session.reviewLearningCards) {
                        Label("Review \(session.learningCount) learning cards", systemImage: "arrow.clockwise")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.hbAccent)
                            .clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
                    }
                    .disabled(session.learningCount == 0)
                    .opacity(session.learningCount == 0 ? 0.45 : 1)

                    Button("Restart all flashcards", action: session.restart)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color.hbAccent)
                        .padding(.vertical, 8)
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
            Text("\(value)")
                .monospacedDigit()
        }
        .font(.callout.weight(.semibold))
        .foregroundStyle(Color.hbTextSecondary)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
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

#Preview("Flashcard") {
    NavigationStack {
        FlashcardsView(cards: [
            Flashcard(
                id: "1",
                prompt: "Which countries make up Great Britain?",
                answer: "England, Scotland and Wales",
                topic: "Chapter 2"
            ),
            Flashcard(
                id: "2",
                prompt: "What is the capital of the United Kingdom?",
                answer: "London",
                topic: "Chapter 2"
            )
        ])
    }
}
