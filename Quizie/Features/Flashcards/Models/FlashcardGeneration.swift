import Foundation

nonisolated struct FlashcardContextBlock: Codable, Equatable, Sendable {
    let id: String
    let text: String
    let isSelected: Bool
    let taxonomy: ContentTaxonomyTags

    init(id: String, text: String, isSelected: Bool, taxonomy: ContentTaxonomyTags = .empty) {
        self.id = id
        self.text = text
        self.isSelected = isSelected
        self.taxonomy = taxonomy
    }
}

nonisolated struct FlashcardGenerationContext: Codable, Equatable, Sendable {
    let chapter: String
    let section: String
    let selection: String
    let context: String
    let blocks: [FlashcardContextBlock]
    let maxCards: Int
    let taxonomyVersion: String
    let taxonomy: ContentTaxonomyTags

    init(chapter: String, section: String, selection: String, context: String, blocks: [FlashcardContextBlock], maxCards: Int, taxonomyVersion: String = "", taxonomy: ContentTaxonomyTags = .empty) {
        self.chapter = chapter
        self.section = section
        self.selection = selection
        self.context = context
        self.blocks = blocks
        self.maxCards = maxCards
        self.taxonomyVersion = taxonomyVersion
        self.taxonomy = taxonomy
    }

    func taxonomy(for sourceBlockIds: [String]) -> ContentTaxonomyTags {
        let sourceIDs = Set(sourceBlockIds)
        let resolved = blocks.filter { sourceIDs.contains($0.id) }.reduce(ContentTaxonomyTags.empty) { $0.merging($1.taxonomy) }
        return resolved.isEmpty ? taxonomy : resolved
    }
}

nonisolated struct GeneratedFlashcard: Codable, Equatable, Sendable {
    let question: String
    let answer: String
    let sourceBlockIds: [String]
    let taxonomy: ContentTaxonomyTags

    init(question: String, answer: String, sourceBlockIds: [String], taxonomy: ContentTaxonomyTags = .empty) {
        self.question = question
        self.answer = answer
        self.sourceBlockIds = sourceBlockIds
        self.taxonomy = taxonomy
    }

    private enum CodingKeys: String, CodingKey {
        case question, answer, sourceBlockIds, taxonomy
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        question = try container.decode(String.self, forKey: .question)
        answer = try container.decode(String.self, forKey: .answer)
        sourceBlockIds = try container.decode([String].self, forKey: .sourceBlockIds)
        taxonomy = try container.decodeIfPresent(ContentTaxonomyTags.self, forKey: .taxonomy) ?? .empty
    }
}

nonisolated struct FlashcardGenerationResponse: Codable, Equatable, Sendable {
    let cards: [GeneratedFlashcard]
}

nonisolated struct FlashcardDraft: Identifiable, Equatable, Sendable {
    let id: UUID
    var question: String
    var answer: String
    let sourceBlockIds: [String]
    let taxonomy: ContentTaxonomyTags

    init(id: UUID = UUID(), generatedCard: GeneratedFlashcard, fallbackTaxonomy: ContentTaxonomyTags = .empty) {
        self.id = id
        question = generatedCard.question
        answer = generatedCard.answer
        sourceBlockIds = generatedCard.sourceBlockIds
        taxonomy = generatedCard.taxonomy.isEmpty ? fallbackTaxonomy : generatedCard.taxonomy
    }

    var isValid: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

@MainActor
enum FlashcardDraftApproval {
    static func save(_ drafts: [FlashcardDraft], chapterNumber: Int?, to memory: FlashcardMemory) {
        for draft in drafts where draft.isValid {
            memory.createCard(prompt: draft.question, answer: draft.answer, chapter: chapterNumber, isDateCard: false, sourceBlockIDs: draft.sourceBlockIds, taxonomy: draft.taxonomy)
        }
    }
}

nonisolated enum FlashcardGenerationContextBuilder {
    static func make(chapter: HandbookChapter, section: HandbookSection, selectedBlockRange: ClosedRange<Int>, selectedTextRange: NSRange? = nil, taxonomyTagger: TaxonomyTagResolver = .empty) -> FlashcardGenerationContext? {
        guard !section.blocks.isEmpty else { return nil }
        let lowerBound = max(0, selectedBlockRange.lowerBound)
        let upperBound = min(section.blocks.count - 1, selectedBlockRange.upperBound)
        guard lowerBound <= upperBound else { return nil }

        let selectedIndexes = lowerBound...upperBound
        let selection: String
        if lowerBound == upperBound, let selectedTextRange,
           let selectedText = substring(section.blocks[lowerBound].plainText, range: selectedTextRange) {
            selection = selectedText
        } else {
            selection = selectedIndexes.map { section.blocks[$0].plainText }.joined(separator: "\n\n")
        }

        let trimmedSelection = selection.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSelection.isEmpty else { return nil }

        let contextLowerBound = max(0, lowerBound - 1)
        let contextUpperBound = min(section.blocks.count - 1, upperBound + 1)
        let contextBlocks = (contextLowerBound...contextUpperBound).map { index in
            let block = section.blocks[index]
            return FlashcardContextBlock(id: block.id, text: block.plainText, isSelected: selectedIndexes.contains(index), taxonomy: taxonomyTagger.tags(forBlockIDs: [block.id]))
        }
        let context = contextBlocks.map { block in
            "[\(block.id)]\(block.isSelected ? " [selected]" : "")\n\(block.text)"
        }.joined(separator: "\n\n")

        let selectedBlockIDs = selectedIndexes.map { section.blocks[$0].id }
        return FlashcardGenerationContext(
            chapter: "\(chapter.number): \(chapter.title)",
            section: section.title,
            selection: trimmedSelection,
            context: context,
            blocks: contextBlocks,
            maxCards: maximumCardCount(selection: trimmedSelection, selectedBlockCount: selectedIndexes.count),
            taxonomyVersion: taxonomyTagger.taxonomyVersion,
            taxonomy: taxonomyTagger.tags(forBlockIDs: selectedBlockIDs)
        )
    }

    static func maximumCardCount(selection: String, selectedBlockCount: Int) -> Int {
        let sentenceCount = selection.split(whereSeparator: { ".!?".contains($0) }).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        if selectedBlockCount == 1, sentenceCount <= 1 { return 1 }
        if selectedBlockCount <= 2 { return min(4, max(2, sentenceCount)) }
        return min(8, max(3, max(selectedBlockCount, sentenceCount)))
    }

    private static func substring(_ text: String, range: NSRange) -> String? {
        let value = text as NSString
        guard range.location >= 0, range.length > 0, NSMaxRange(range) <= value.length else { return nil }
        return value.substring(with: range)
    }
}
