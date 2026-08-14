import SwiftUI

struct BookmarkedQuestionsView: View {
    let questionRepository: any QuestionRepository
    let questionSourceResolver: QuizQuestionSourceResolver

    @AppStorage(QuestionBookmarks.storageKey) private var bookmarkedQuestionsData = Data()
    @State private var questions: [QuizQuestion] = []
    @State private var loadError: String?

    private var bookmarkedQuestionIDs: Set<String> {
        QuestionBookmarks.ids(from: bookmarkedQuestionsData)
    }

    var body: some View {
        Group {
            if let loadError {
                ContentUnavailableView("Bookmarks Unavailable", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else if questions.isEmpty {
                ContentUnavailableView("No Bookmarks", systemImage: "bookmark", description: Text("Bookmark questions during a quiz and they’ll appear here."))
            } else {
                List {
                    Section {
                        ForEach(questions) { question in
                            NavigationLink {
                                BookmarkedQuestionDetailView(question: question, source: questionSourceResolver.source(for: question))
                            } label: {
                                BookmarkedQuestionRow(question: question)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    removeBookmark(question.id)
                                } label: {
                                    Label("Remove", systemImage: "bookmark.slash")
                                }
                            }
                        }
                    } header: {
                        Text("\(questions.count) saved \(questions.count == 1 ? "question" : "questions")")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.hbBackground)
        .navigationTitle("Bookmarks")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: bookmarkedQuestionsData) {
            loadBookmarkedQuestions()
        }
    }

    private func loadBookmarkedQuestions() {
        guard !bookmarkedQuestionIDs.isEmpty else {
            questions = []
            loadError = nil
            return
        }

        do {
            questions = try questionRepository.questions(count: .max, seed: "bookmarked-questions")
                .filter { bookmarkedQuestionIDs.contains($0.id) }
                .sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }
            loadError = nil
        } catch {
            questions = []
            loadError = error.localizedDescription
        }
    }

    private func removeBookmark(_ questionID: String) {
        var ids = bookmarkedQuestionIDs
        ids.remove(questionID)
        bookmarkedQuestionsData = QuestionBookmarks.data(for: ids)
    }
}

private struct BookmarkedQuestionRow: View {
    let question: QuizQuestion

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bookmark.fill")
                .appFont(.subheadline.weight(.semibold))
                .foregroundStyle(Color(hex: "#B62373"))
                .frame(width: 34, height: 34)
                .background(Color(hex: "#FCE1EE"), in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 6) {
                Text(question.question)
                    .appFont(.callout.weight(.medium))
                    .foregroundStyle(Color.hbTextPrimary)
                    .lineLimit(3)

                Text(question.year.isEmpty ? "Saved question" : question.year)
                    .appFont(.caption)
                    .foregroundStyle(Color.hbTextMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 5)
    }
}

private struct BookmarkedQuestionDetailView: View {
    let question: QuizQuestion
    let source: QuizQuestionSource?

    @AppStorage(QuestionBookmarks.storageKey) private var bookmarkedQuestionsData = Data()
    @State private var isShowingAnswer = false

    private var isBookmarked: Bool {
        QuestionBookmarks.ids(from: bookmarkedQuestionsData).contains(question.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(question.question)
                    .appFont(.title3.weight(.semibold))
                    .foregroundStyle(Color.hbTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                        choiceRow(choice, index: index)
                    }
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowingAnswer.toggle()
                    }
                } label: {
                    Label(isShowingAnswer ? "Hide Answer" : "Show Answer", systemImage: isShowingAnswer ? "eye.slash" : "eye")
                        .appFont(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.hbAccent, in: RoundedRectangle(cornerRadius: HBRadius.md))
                }
                .buttonStyle(.plain)

                if isShowingAnswer, let source {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Handbook reference", systemImage: "book.closed")
                            .appFont(.caption.weight(.semibold))
                            .foregroundStyle(Color.hbTextMuted)

                        Text(source.taxonomyLabel)
                            .appFont(.callout.weight(.semibold))
                            .foregroundStyle(Color.hbTextPrimary)

                        Text("\(source.handbookLocation) · \(source.sectionTitle)")
                            .appFont(.footnote)
                            .foregroundStyle(Color.hbTextSecondary)

                        if let passage = source.passage {
                            Text(passage)
                                .appFont(.callout)
                                .foregroundStyle(Color.hbTextSecondary)
                                .padding(.top, 4)
                        }
                    }
                    .padding(16)
                    .background(Color.hbSurface, in: RoundedRectangle(cornerRadius: HBRadius.md))
                    .overlay(RoundedRectangle(cornerRadius: HBRadius.md).stroke(Color.hbBorder, lineWidth: 1))
                }
            }
            .padding(16)
        }
        .background(Color.hbBackground)
        .navigationTitle("Bookmarked Question")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: toggleBookmark) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Bookmark question")
            }
        }
    }

    private func choiceRow(_ choice: String, index: Int) -> some View {
        let isCorrect = question.correctIndices.contains(index)
        let color = isShowingAnswer && isCorrect ? Color(hex: "#1E8449") : Color.hbTextPrimary
        let background = isShowingAnswer && isCorrect ? Color(hex: "#D5F5E3") : Color.hbSurface

        return HStack(spacing: 12) {
            Text("\(index + 1)")
                .appFont(.footnote.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.1), in: Circle())

            Text(choice)
                .appFont(.callout)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isShowingAnswer && isCorrect {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(color)
            }
        }
        .padding(14)
        .background(background, in: RoundedRectangle(cornerRadius: HBRadius.md))
        .overlay(RoundedRectangle(cornerRadius: HBRadius.md).stroke(isShowingAnswer && isCorrect ? color.opacity(0.35) : Color.hbBorder, lineWidth: 1))
    }

    private func toggleBookmark() {
        var ids = QuestionBookmarks.ids(from: bookmarkedQuestionsData)
        if isBookmarked {
            ids.remove(question.id)
        } else {
            ids.insert(question.id)
        }
        bookmarkedQuestionsData = QuestionBookmarks.data(for: ids)
    }
}

#Preview("Bookmarked Questions") {
    let questions = PreviewQuizEngine.sampleEngine.session?.questions ?? []
    let defaults = UserDefaults(suiteName: "BookmarkedQuestionsViewPreview.Saved")!
    defaults.set(QuestionBookmarks.data(for: Set(questions.prefix(2).map(\.id))), forKey: QuestionBookmarks.storageKey)

    return NavigationStack {
        BookmarkedQuestionsView(questionRepository: InMemoryQuestionRepository(questions), questionSourceResolver: .empty)
    }
    .defaultAppStorage(defaults)
}

#Preview("No Bookmarked Questions") {
    let defaults = UserDefaults(suiteName: "BookmarkedQuestionsViewPreview.Empty")!
    defaults.set(Data(), forKey: QuestionBookmarks.storageKey)

    return NavigationStack {
        BookmarkedQuestionsView(questionRepository: InMemoryQuestionRepository([]), questionSourceResolver: .empty)
    }
    .defaultAppStorage(defaults)
}
