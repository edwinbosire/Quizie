import SwiftUI

struct FlashcardGenerationPresentation: Identifiable {
    let id = UUID()
    let context: FlashcardGenerationContext
    let chapterNumber: Int?
}

struct GeneratedFlashcardPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let presentation: FlashcardGenerationPresentation
    let aiInference: any AIInferenceService
    let memory: FlashcardMemory

    @State private var cards: [FlashcardDraft] = []
    @State private var isGenerating = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isGenerating {
                    generationProgress
                } else if let errorMessage {
                    generationError(errorMessage)
                } else {
                    cardEditor
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                if !cards.isEmpty, !isGenerating {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save all", action: saveAll)
                            .disabled(cards.contains(where: { !$0.isValid }))
                    }
                }
            }
        }
        .interactiveDismissDisabled(isGenerating)
        .task { await generate() }
    }

    private var navigationTitle: String {
        if isGenerating { return "Creating flashcards" }
        guard errorMessage == nil else { return "Create flashcards" }
        return "\(cards.count) flashcard\(cards.count == 1 ? "" : "s") created"
    }

    private var generationProgress: some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)
            Text("Finding testable facts in your selection…")
                .appFont(.callout.weight(.semibold))
                .foregroundStyle(Color.hbTextPrimary)
            Text("Only the supplied handbook context is used.")
                .appFont(.footnote)
                .foregroundStyle(Color.hbTextMuted)
        }
        .padding(32)
    }

    private func generationError(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn’t create flashcards", systemImage: "sparkles.rectangle.stack")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task { await generate() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var cardEditor: some View {
        Form {
            Section {
                Text("Review and edit these drafts. Nothing is added to your revision deck until you save.")
                    .appFont(.footnote)
                    .foregroundStyle(Color.hbTextSecondary)
            }

            ForEach($cards) { $card in
                Section {
                    TextField("Question", text: $card.question, axis: .vertical)
                        .lineLimit(2...6)
                    TextField("Answer", text: $card.answer, axis: .vertical)
                        .lineLimit(3...10)

                    HStack {
                        Label("\(card.sourceBlockIds.count) source block\(card.sourceBlockIds.count == 1 ? "" : "s")", systemImage: "text.quote")
                            .appFont(.caption)
                            .foregroundStyle(Color.hbTextMuted)
                        Spacer()
                        Button("Delete", role: .destructive) {
                            cards.removeAll { $0.id == card.id }
                        }
                        .appFont(.caption.weight(.semibold))
                    }
                } header: {
                    Text("Flashcard")
                }
            }

            Section {
                Button {
                    Task { await generate() }
                } label: {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .disabled(isGenerating)
            }
        }
    }

    @MainActor
    private func generate() async {
        isGenerating = true
        errorMessage = nil
        do {
            let generated = try await aiInference.generateFlashcards(from: presentation.context)
            try Task.checkCancellation()
            cards = generated.map { FlashcardDraft(generatedCard: $0) }
        } catch is CancellationError {
            return
        } catch {
            cards = []
            errorMessage = error.localizedDescription
        }
        isGenerating = false
    }

    private func saveAll() {
        FlashcardDraftApproval.save(cards, chapterNumber: presentation.chapterNumber, to: memory)
        dismiss()
    }
}
