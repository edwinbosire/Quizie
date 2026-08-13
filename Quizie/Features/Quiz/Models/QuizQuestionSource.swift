import Foundation

struct QuizQuestionSource: Identifiable, Equatable {
    let conceptID: String
    let taxonomyPath: [String]
    let chapterNumber: String
    let chapterTitle: String
    let sectionTitle: String
    let blockID: String?
    let passage: String?

    var id: String { "\(conceptID)-\(blockID ?? "source")" }
    var taxonomyLabel: String { taxonomyPath.joined(separator: " › ") }
    var handbookLocation: String { "\(chapterNumber) · \(chapterTitle)" }
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

        return QuizQuestionSource(
            conceptID: conceptID,
            taxonomyPath: path.map(\.displayName),
            chapterNumber: location.0.number,
            chapterTitle: location.0.title,
            sectionTitle: location.1.title,
            blockID: selectedPassage?.blockID,
            passage: selectedPassage?.text
        )
    }

    private func passageCandidates(for references: [TaxonomyHandbookReference]) -> [PassageCandidate] {
        var seenBlockIDs = Set<String>()
        var candidates: [PassageCandidate] = []
        for reference in references {
            guard let chapter = chapters.first(where: { $0.contentID == reference.chapterId }),
                  let section = chapter.sections.first(where: { $0.id == reference.sectionId }) else { continue }
            for blockID in reference.blockIds where seenBlockIDs.insert(blockID).inserted {
                guard let block = section.blocks.first(where: { $0.id == blockID }), isPassage(block) else { continue }
                candidates.append(PassageCandidate(chapter: chapter, section: section, blockID: block.id, text: block.plainText))
            }
        }
        return candidates
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
        case .paragraph, .blockquote, .bulletList:
            return true
        case .subheading, .subheading2, .checkUnderstand, .dataTable:
            return false
        }
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
    let blockID: String
    let text: String
}
