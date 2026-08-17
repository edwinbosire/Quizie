import Foundation

struct QuizQuestionSource: Identifiable, Equatable {
    let conceptID: String
    let taxonomyPath: [String]
    let chapterID: String
    let sectionID: String
    let chapterNumber: String
    let chapterTitle: String
    let sectionTitle: String
    let blockID: String?
    let hintBlocks: [QuizHintBlock]

    var id: String { "\(conceptID)-\(blockID ?? "source")" }
    var taxonomyLabel: String { taxonomyPath.joined(separator: " › ") }
    var handbookLocation: String { "\(chapterNumber) · \(chapterTitle)" }
    var hasHint: Bool { !hintBlocks.isEmpty }
    var passage: String? { hasHint ? hintBlocks.map(\.plainText).joined(separator: " ") : nil }
}

struct QuizHintBlock: Identifiable, Equatable {
    let id: String
    let content: QuizHintBlockContent

    var plainText: String {
        switch content {
        case .paragraph(let text), .blockquote(let text): return text
        case .bulletList(let items): return items.joined(separator: " ")
        case .dataTable(let headers, let rows): return (headers + rows.flatMap { $0 }).joined(separator: " ")
        }
    }
}

enum QuizHintBlockContent: Equatable {
    case paragraph(String)
    case bulletList([String])
    case blockquote(String)
    case dataTable(headers: [String], rows: [[String]])
}

struct QuizQuestionSourceResolver {
    static let empty = QuizQuestionSourceResolver(chapters: [], taxonomyTagger: .empty)

    let chapters: [HandbookChapter]
    let taxonomyTagger: TaxonomyTagResolver

    func source(for question: QuizQuestion) -> QuizQuestionSource? {
        guard let conceptID = question.taxonomy.primaryConceptId else { return nil }
        let path = taxonomyTagger.conceptPath(for: conceptID)
        guard !path.isEmpty else { return nil }

        let references = taxonomyTagger.handbookReferences(for: conceptID)
        let candidates = passageCandidates(for: references)
        let selectedPassage = candidates.max { passageScore($0.text, for: question, conceptPath: path) < passageScore($1.text, for: question, conceptPath: path) }
        let location = selectedPassage.map { ($0.chapter, $0.section) } ?? firstLocation(for: references)
        guard let location else { return nil }
        let hintBlocks = selectedPassage.map(hintBlocks(around:)) ?? []

        return QuizQuestionSource(
            conceptID: conceptID,
            taxonomyPath: path.map(\.displayName),
            chapterID: location.0.contentID,
            sectionID: location.1.id,
            chapterNumber: location.0.number,
            chapterTitle: location.0.title,
            sectionTitle: location.1.title,
            blockID: selectedPassage?.blockID,
            hintBlocks: hintBlocks
        )
    }

    private func passageCandidates(for references: [TaxonomyHandbookReference]) -> [PassageCandidate] {
        var seenBlockIDs = Set<String>()
        var candidates: [PassageCandidate] = []
        for reference in references {
            guard let chapter = chapters.first(where: { $0.contentID == reference.chapterId }),
                  let section = chapter.sections.first(where: { $0.id == reference.sectionId }) else { continue }
            for blockID in reference.blockIds where seenBlockIDs.insert(blockID).inserted {
                guard let blockIndex = section.blocks.firstIndex(where: { $0.id == blockID }), isPassage(section.blocks[blockIndex]) else { continue }
                let block = section.blocks[blockIndex]
                candidates.append(PassageCandidate(chapter: chapter, section: section, blockIndex: blockIndex, blockID: block.id, text: block.plainText))
            }
        }
        return candidates
    }

    private func hintBlocks(around candidate: PassageCandidate) -> [QuizHintBlock] {
        let blocks = candidate.section.blocks
        var lowerBound = candidate.blockIndex
        var upperBound = candidate.blockIndex

        if isBulletList(blocks[candidate.blockIndex]) || (lowerBound > 0 && isBulletList(blocks[lowerBound - 1])) {
            while lowerBound > 0 && isBulletList(blocks[lowerBound - 1]) { lowerBound -= 1 }
            if lowerBound > 0 && isParagraphIntroducingList(blocks[lowerBound - 1]) { lowerBound -= 1 }
        }
        while upperBound + 1 < blocks.count && isBulletList(blocks[upperBound + 1]) { upperBound += 1 }

        return blocks[lowerBound...upperBound].compactMap(makeHintBlock)
    }

    private func makeHintBlock(_ block: ContentBlock) -> QuizHintBlock? {
        switch block.content {
        case .paragraph(let text):
            return QuizHintBlock(id: block.id, content: .paragraph(text.strippingMarkdownBold))
        case .blockquote(let text):
            return QuizHintBlock(id: block.id, content: .blockquote(text))
        case .bulletList(let items):
            return QuizHintBlock(id: block.id, content: .bulletList(items.map { $0.text.raw.strippingMarkdownBold }))
        case .dataTable(let headers, let rows):
            return QuizHintBlock(id: block.id, content: .dataTable(headers: headers, rows: rows))
        case .subheading, .subheading2, .checkUnderstand:
            return nil
        }
    }

    private func firstLocation(for references: [TaxonomyHandbookReference]) -> (HandbookChapter, HandbookSection)? {
        for reference in references {
            guard let chapter = chapters.first(where: { $0.contentID == reference.chapterId }),
                  let section = chapter.sections.first(where: { $0.id == reference.sectionId }) else { continue }
            return (chapter, section)
        }
        return nil
    }

    private func isPassage(_ block: ContentBlock) -> Bool {
        switch block.content {
        case .paragraph, .blockquote, .bulletList, .dataTable:
            return true
        case .subheading, .subheading2, .checkUnderstand:
            return false
        }
    }

    private func isBulletList(_ block: ContentBlock) -> Bool {
        if case .bulletList = block.content { return true }
        return false
    }

    private func isParagraphIntroducingList(_ block: ContentBlock) -> Bool {
        if case .paragraph(let text) = block.content { return text.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix(":") }
        return false
    }

    private func passageScore(_ passage: String, for question: QuizQuestion, conceptPath: [TaxonomyConcept]) -> Int {
        let normalizedPassage = normalized(passage)
        let answerTerms = question.correctChoices + (question.year.isEmpty ? [] : [question.year])
        let exactAnswerScore = answerTerms.reduce(0) { score, term in
            score + (contains(term, in: normalizedPassage) ? 12 : 0)
        }
        let questionScore = meaningfulWords(in: question.question).reduce(0) { score, word in
            score + (contains(word, in: normalizedPassage) ? 2 : 0)
        }
        let taxonomyScore = meaningfulWords(in: conceptPath.last?.displayName ?? "").reduce(0) { score, word in
            score + (contains(word, in: normalizedPassage) ? 1 : 0)
        }
        return exactAnswerScore + questionScore + taxonomyScore
    }

    private func meaningfulWords(in text: String) -> Set<String> {
        let ignored = Set(["what", "when", "where", "which", "who", "whose", "were", "was", "does", "from", "with", "that", "this", "there", "their", "about", "into", "begin"])
        return Set(normalized(text).split(separator: " ").map(String.init).filter { $0.count > 3 && !ignored.contains($0) })
    }

    private func contains(_ term: String, in normalizedPassage: String) -> Bool {
        let normalizedTerm = normalized(term)
        guard !normalizedTerm.isEmpty else { return false }
        return " \(normalizedPassage) ".contains(" \(normalizedTerm) ")
    }

    private func normalized(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_GB"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

private struct PassageCandidate {
    let chapter: HandbookChapter
    let section: HandbookSection
    let blockIndex: Int
    let blockID: String
    let text: String
}

private extension String {
    var strippingMarkdownBold: String { replacingOccurrences(of: "**", with: "") }
}
