import Foundation

enum ContentReviewSettings {
    static let storageKey = "contentReviewModeEnabled"
    static let feedbackAddress = "development@fancyapps.com"
}

enum ContentReportKind: String, Sendable {
    case question = "Question"
    case flashcard = "Flashcard"
}

struct ContentReportContent: Identifiable, Equatable, Sendable {
    let kind: ContentReportKind
    let contentID: String
    let prompt: String
    let answerContext: String

    var id: String { "\(kind.rawValue)-\(contentID)" }

    static func question(_ question: QuizQuestion) -> ContentReportContent {
        let choices = question.choices.enumerated().map { index, choice in
            let marker = question.correctIndices.contains(index) ? "✓" : "–"
            return "\(marker) \(index + 1). \(choice)"
        }.joined(separator: "\n")
        return ContentReportContent(kind: .question, contentID: question.id, prompt: question.question, answerContext: choices)
    }

    static func flashcard(_ flashcard: Flashcard) -> ContentReportContent {
        ContentReportContent(kind: .flashcard, contentID: flashcard.id, prompt: flashcard.prompt, answerContext: flashcard.answer)
    }
}

enum ContentIssueCategory: String, CaseIterable, Identifiable, Sendable {
    case incorrectAnswer = "Incorrect answer"
    case factualError = "Factual error"
    case outdated = "Out of date"
    case typo = "Typo or grammar"
    case unclear = "Unclear wording"
    case other = "Other"

    var id: String { rawValue }
}

enum ContentFeedbackEmail {
    static func reportURL(content: ContentReportContent, category: ContentIssueCategory, details: String) -> URL? {
        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let contextTitle = content.kind == .question ? "Choices (✓ = configured answer)" : "Answer"
        let body = """
        I found a content issue in BritReady.

        Type: \(content.kind.rawValue)
        Content ID: \(content.contentID)
        Issue: \(category.rawValue)

        Details:
        \(trimmedDetails.isEmpty ? "Please describe the issue here." : trimmedDetails)

        Prompt:
        \(content.prompt)

        \(contextTitle):
        \(content.answerContext)
        """
        return emailURL(subject: "[BritReady] \(content.kind.rawValue) issue – \(content.contentID)", body: body)
    }

    static func analysisURL(_ analysis: ContentQualityAnalysis) -> URL? {
        let findingPreview = analysis.findings.prefix(30).map { "• [\($0.area.rawValue)] \($0.contentID): \($0.message)" }.joined(separator: "\n")
        let remaining = max(analysis.findings.count - 30, 0)
        let remainder = remaining == 0 ? "" : "\n• …and \(remaining) more findings in the in-app dashboard."
        let body = """
        BritReady content quality analysis

        Questions checked: \(analysis.questionCount)
        Guide flashcards checked: \(analysis.flashcardCount)
        Handbook blocks checked: \(analysis.handbookBlockCount)
        Findings: \(analysis.findings.count)

        Findings preview:
        \(findingPreview.isEmpty ? "No automated structural findings." : findingPreview)\(remainder)

        Note: These automated checks cover structure, identity and flashcard recall quality. Factual accuracy still requires editorial review.
        """
        return emailURL(subject: "[BritReady] Content quality analysis", body: body)
    }

    private static func emailURL(subject: String, body: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = ContentReviewSettings.feedbackAddress
        components.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body)]
        return components.url
    }
}

enum ContentQualityArea: String, CaseIterable, Sendable {
    case questions = "Questions"
    case flashcards = "Flashcards"
    case handbook = "Handbook"

    var systemImage: String {
        switch self {
        case .questions: return "checkmark.circle"
        case .flashcards: return "rectangle.stack"
        case .handbook: return "book.closed"
        }
    }
}

enum ContentQualitySeverity: Int, Comparable, Sendable {
    case note
    case warning
    case error

    static func < (lhs: ContentQualitySeverity, rhs: ContentQualitySeverity) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct ContentQualityFinding: Identifiable, Equatable, Sendable {
    let id = UUID()
    let area: ContentQualityArea
    let contentID: String
    let message: String
    let severity: ContentQualitySeverity
}

struct ContentQualityAnalysis: Equatable, Sendable {
    let questionCount: Int
    let flashcardCount: Int
    let handbookBlockCount: Int
    let findings: [ContentQualityFinding]

    func findingCount(for area: ContentQualityArea) -> Int { findings.count { $0.area == area } }
}

enum ContentQualityAnalyzer {
    static func analyze(questions: [QuizQuestion], guideCards: [Flashcard], flashcardAudit: [BundledFlashcardAuditEntry], chapters: [HandbookChapter]) -> ContentQualityAnalysis {
        var findings = questionFindings(questions)
        findings.append(contentsOf: flashcardFindings(cards: guideCards, audit: flashcardAudit))
        findings.append(contentsOf: handbookFindings(chapters))
        findings.sort {
            if $0.severity != $1.severity { return $0.severity > $1.severity }
            if $0.area != $1.area { return $0.area.rawValue < $1.area.rawValue }
            return $0.contentID < $1.contentID
        }
        return ContentQualityAnalysis(
            questionCount: questions.count,
            flashcardCount: guideCards.count,
            handbookBlockCount: chapters.flatMap(\.sections).flatMap(\.blocks).count,
            findings: findings
        )
    }

    private static func questionFindings(_ questions: [QuizQuestion]) -> [ContentQualityFinding] {
        var findings: [ContentQualityFinding] = []
        findings.append(contentsOf: duplicateFindings(values: questions.map { ($0.id, $0.id) }, message: "Duplicate question ID"))

        let prompts = questions.map { ($0.id, normalized($0.question)) }.filter { !$0.1.isEmpty }
        findings.append(contentsOf: duplicateFindings(values: prompts, message: "Prompt is duplicated by another question", severity: .warning))

        for question in questions {
            if question.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                findings.append(questionFinding(question.id, "Question prompt is empty", .error))
            }
            if question.choices.count < 2 {
                findings.append(questionFinding(question.id, "Question has fewer than two choices", .error))
            }
            if question.choices.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                findings.append(questionFinding(question.id, "Question contains an empty choice", .error))
            }
            let normalizedChoices = question.choices.map(normalized)
            if Set(normalizedChoices).count != normalizedChoices.count {
                findings.append(questionFinding(question.id, "Question contains duplicate choices", .error))
            }
            if question.correctIndices.isEmpty {
                findings.append(questionFinding(question.id, "Question has no configured correct answer", .error))
            } else if question.correctIndices.contains(where: { !question.choices.indices.contains($0) }) {
                findings.append(questionFinding(question.id, "Correct answer points outside the choices", .error))
            }
            if question.taxonomy.conceptIds.isEmpty || question.taxonomy.primaryConceptId == nil {
                findings.append(questionFinding(question.id, "Question is missing taxonomy metadata", .warning))
            }
        }
        return findings
    }

    private static func flashcardFindings(cards: [Flashcard], audit: [BundledFlashcardAuditEntry]) -> [ContentQualityFinding] {
        var findings: [ContentQualityFinding] = []
        findings.append(contentsOf: duplicateFindings(values: cards.map { ($0.id, $0.id) }, area: .flashcards, message: "Duplicate flashcard ID"))
        for card in cards {
            if !FlashcardRecallStyle.isValid(question: card.prompt, answer: card.answer) {
                findings.append(ContentQualityFinding(area: .flashcards, contentID: card.id, message: "Flashcard does not meet concise recall rules", severity: .error))
            }
        }
        for entry in audit {
            let issueNames = entry.issues.map(\.displayName).joined(separator: ", ")
            switch entry.outcome {
            case .repaired:
                findings.append(ContentQualityFinding(area: .flashcards, contentID: entry.questionID, message: "Generated flashcard was repaired: \(issueNames)", severity: .note))
            case .excluded:
                findings.append(ContentQualityFinding(area: .flashcards, contentID: entry.questionID, message: "Question was excluded from flashcards: \(issueNames)", severity: .warning))
            }
        }
        return findings
    }

    private static func handbookFindings(_ chapters: [HandbookChapter]) -> [ContentQualityFinding] {
        var findings: [ContentQualityFinding] = []
        findings.append(contentsOf: duplicateFindings(values: chapters.map { ($0.contentID, $0.contentID) }, area: .handbook, message: "Duplicate chapter ID"))
        let sections = chapters.flatMap(\.sections)
        findings.append(contentsOf: duplicateFindings(values: sections.map { ($0.id, $0.id) }, area: .handbook, message: "Duplicate section ID"))
        let blocks = sections.flatMap(\.blocks)
        findings.append(contentsOf: duplicateFindings(values: blocks.map { ($0.id, $0.id) }, area: .handbook, message: "Duplicate content block ID"))

        for chapter in chapters {
            if chapter.contentID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                findings.append(ContentQualityFinding(area: .handbook, contentID: chapter.number, message: "Chapter is missing a stable ID", severity: .error))
            }
            if chapter.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                findings.append(ContentQualityFinding(area: .handbook, contentID: chapter.contentID, message: "Chapter title is empty", severity: .error))
            }
        }
        for section in sections {
            if section.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                findings.append(ContentQualityFinding(area: .handbook, contentID: section.id, message: "Section title is empty", severity: .error))
            }
            if section.blocks.isEmpty {
                findings.append(ContentQualityFinding(area: .handbook, contentID: section.id, message: "Section has no content blocks", severity: .warning))
            }
        }
        for block in blocks where block.plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            findings.append(ContentQualityFinding(area: .handbook, contentID: block.id, message: "Content block is empty", severity: .error))
        }
        return findings
    }

    private static func questionFinding(_ id: String, _ message: String, _ severity: ContentQualitySeverity) -> ContentQualityFinding {
        ContentQualityFinding(area: .questions, contentID: id, message: message, severity: severity)
    }

    private static func duplicateFindings(values: [(id: String, value: String)], area: ContentQualityArea = .questions, message: String, severity: ContentQualitySeverity = .error) -> [ContentQualityFinding] {
        let grouped = Dictionary(grouping: values, by: \.value)
        return grouped.values.filter { $0.count > 1 }.flatMap { group in
            group.map { ContentQualityFinding(area: area, contentID: $0.id, message: message, severity: severity) }
        }
    }

    nonisolated private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private extension BundledFlashcardIssue {
    var displayName: String {
        switch self {
        case .multipleAnswers: return "multiple answers"
        case .nonAtomicPrompt: return "non-atomic prompt"
        case .nonMinimalAnswer: return "non-minimal answer"
        }
    }
}
