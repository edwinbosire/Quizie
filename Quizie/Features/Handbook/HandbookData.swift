import Foundation

// MARK: - Content Models

struct HandbookChapter: Identifiable {
    let id: Int
    let number: String
    let title: String
    let pillLabels: [String]
	let sections: [HandbookSection]
}

struct HandbookSection: Identifiable {
    let id: String
    let title: String
    let blocks: [ContentBlock]
}

enum ContentBlock {
    case paragraph(String)
    case subheading(String)
    case subheading2(String)          // h4 equivalent
    case bulletList([BulletItem])
    case checkUnderstand([String])
    case blockquote(String)
    case dataTable(headers: [String], rows: [[String]])
}

struct BulletItem: Identifiable {
    let id = UUID()
    let text: AttributedContent  // supports bold inline
    let subItems: [String]

    init(_ text: String, subItems: [String] = []) {
        self.text = AttributedContent(raw: text)
        self.subItems = subItems
    }
}

struct AttributedContent {
    let raw: String
}

// MARK: - JSON Codable Types (private)

private struct HandbookJSON: Codable {
    let chapters: [ChapterJSON]
}

private struct ChapterJSON: Codable {
    let id: String
    let title: String
    let sections: [SectionJSON]
}

private struct SectionJSON: Codable {
    let id: String
    let title: String
    let content: [ContentItemJSON]
    let facts: [String]?
}

private struct ContentItemJSON: Codable {
    let type: String
    let text: String?
    let level: Int?
    let items: [String]?
}

// MARK: - Handbook document decoding

enum HandbookDocumentDecoder {
    static func decode(_ data: Data, decoder: JSONDecoder = JSONDecoder()) throws -> [HandbookChapter] {
        let handbook = try decoder.decode(HandbookJSON.self, from: data)
        return handbook.chapters.enumerated().map { index, chapterJSON in
            let sections = chapterJSON.sections.enumerated().map { sectionIndex, sectionJSON in
                let blocks = buildBlocks(from: sectionJSON.content, facts: sectionJSON.facts)
                return HandbookSection(
                    id: sectionJSON.id.isEmpty ? "c\(index + 1)s\(sectionIndex)" : sectionJSON.id,
                    title: sectionJSON.title,
                    blocks: blocks
                )
            }

            let pillLabels = sections.map { $0.title }
            let (number, title) = parseChapterTitle(chapterJSON.title, fallbackIndex: index + 1)

            return HandbookChapter(
                id: index,
                number: number,
                title: title,
                pillLabels: pillLabels,
                sections: sections
            )
        }
    }

    /// Parse "Chapter 1 : The values and principles of the UK" into ("Chapter 1", "The values and principles of the UK")
    private static func parseChapterTitle(_ raw: String, fallbackIndex: Int) -> (number: String, title: String) {
        if let range = raw.range(of: #"\s*:\s*"#, options: .regularExpression) {
            let number = String(raw[raw.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let title = String(raw[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !number.isEmpty && !title.isEmpty {
                return (number, title)
            }
        }
        return ("Chapter \(fallbackIndex)", raw)
    }

    // MARK: - Block Building

    /// Convert the section's structured content + facts array into ContentBlock values.
    /// Consecutive paragraphs that begin with a "·"/"•" bullet marker are merged into a bulletList.
    /// The `facts` array (if non-empty) becomes a trailing `.checkUnderstand` block.
    private static func buildBlocks(from items: [ContentItemJSON], facts: [String]?) -> [ContentBlock] {
        var blocks: [ContentBlock] = []
        var bulletBuffer: [BulletItem] = []

        func flushBullets() {
            if !bulletBuffer.isEmpty {
                blocks.append(.bulletList(bulletBuffer))
                bulletBuffer.removeAll()
            }
        }

        for item in items {
            switch item.type {
            case "paragraph":
                let raw = item.text ?? ""
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }

                if isBulletPrefixed(trimmed) {
                    bulletBuffer.append(BulletItem(stripBulletPrefix(trimmed)))
                } else {
                    flushBullets()
                    blocks.append(.paragraph(trimmed))
                }

            case "bulletList":
                flushBullets()
                let bulletItems = (item.items ?? [])
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .map { BulletItem($0) }
                if !bulletItems.isEmpty {
                    blocks.append(.bulletList(bulletItems))
                }

            case "heading":
                flushBullets()
                let headingText = (item.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if headingText.isEmpty { continue }
                if (item.level ?? 3) >= 4 {
                    blocks.append(.subheading2(headingText))
                } else {
                    blocks.append(.subheading(headingText))
                }

            default:
                continue
            }
        }
        flushBullets()

        if let facts = facts {
            let cleaned = facts
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !cleaned.isEmpty {
                blocks.append(.checkUnderstand(cleaned))
            }
        }

        return blocks
    }

    private static func isBulletPrefixed(_ text: String) -> Bool {
        text.hasPrefix("·") || text.hasPrefix("•")
    }

    /// Strip a leading "·"/"•" marker plus any following whitespace (including non-breaking spaces).
    private static func stripBulletPrefix(_ text: String) -> String {
        var s = text
        while s.hasPrefix("·") || s.hasPrefix("•") {
            s = String(s.dropFirst())
        }
        s = s.replacingOccurrences(of: "\u{00A0}", with: " ")
        return s.trimmingCharacters(in: .whitespaces)
    }
}
