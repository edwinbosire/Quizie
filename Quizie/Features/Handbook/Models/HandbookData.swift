import Foundation

// MARK: - Content Models

nonisolated struct HandbookChapter: Identifiable, Sendable, Equatable {
    let id: Int
    /// Stable identity authored in handbook.json. `id` remains display order.
    let contentID: String
    let number: String
    let title: String
    let pillLabels: [String]
	let sections: [HandbookSection]
}

nonisolated struct HandbookSection: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let blocks: [ContentBlock]
}

nonisolated struct ContentBlock: Identifiable, Sendable, Equatable {
    let id: String
    let content: ContentBlockContent
}

nonisolated enum ContentBlockContent: Sendable, Equatable {
    case paragraph(String)
    case subheading(String)
    case subheading2(String)          // h4 equivalent
    case bulletList([BulletItem])
    case checkUnderstand([String])
    case blockquote(String)
    case dataTable(headers: [String], rows: [[String]])
}

nonisolated struct BulletItem: Identifiable, Sendable, Equatable {
    let id = UUID()
    let text: AttributedContent  // supports bold inline
    let subItems: [String]

    init(_ text: String, subItems: [String] = []) {
        self.text = AttributedContent(raw: text)
        self.subItems = subItems
    }
}

nonisolated struct AttributedContent: Sendable, Equatable {
    let raw: String
}

// MARK: - JSON Codable Types (private)

nonisolated private struct HandbookJSON: Codable {
    let contentVersion: Int
    let identityMigrations: ContentIdentityMigrations
    let chapters: [ChapterJSON]

    enum CodingKeys: String, CodingKey {
        case contentVersion = "content_version"
        case identityMigrations = "identity_migrations"
        case chapters
    }
}

nonisolated struct ContentIdentityMigrations: Codable, Equatable, Sendable {
    let renamedChapterIDs: [String: String]
    let renamedSectionIDs: [String: String]
    let renamedBlockIDs: [String: String]
    let removedBlockIDs: [String]

    enum CodingKeys: String, CodingKey {
        case renamedChapterIDs = "renamed_chapter_ids"
        case renamedSectionIDs = "renamed_section_ids"
        case renamedBlockIDs = "renamed_block_ids"
        case removedBlockIDs = "removed_block_ids"
    }
}

nonisolated struct HandbookDocument: Sendable {
    let contentVersion: Int
    let identityMigrations: ContentIdentityMigrations
    let chapters: [HandbookChapter]
    var validBlockIDs: Set<String> { Set(chapters.flatMap(\.sections).flatMap(\.blocks).map(\.id)) }
}

nonisolated private struct ChapterJSON: Codable {
    let id: String
    let title: String
    let sections: [SectionJSON]
}

nonisolated private struct SectionJSON: Codable {
    let id: String
    let title: String
    let content: [ContentItemJSON]
    let facts: [String]?
    let factsID: String?

    enum CodingKeys: String, CodingKey {
        case id, title, content, facts
        case factsID = "facts_id"
    }
}

nonisolated private struct ContentItemJSON: Codable {
    let id: String
    let type: String
    let text: String?
    let level: Int?
    let items: [String]?
}

// MARK: - Handbook document decoding

nonisolated enum HandbookDocumentDecoder {
    nonisolated static func decode(_ data: Data, decoder: JSONDecoder = JSONDecoder()) throws -> HandbookDocument {
        let handbook = try decoder.decode(HandbookJSON.self, from: data)
        let chapters = handbook.chapters.enumerated().map { index, chapterJSON in
            let sections = chapterJSON.sections.enumerated().map { sectionIndex, sectionJSON in
                let blocks = buildBlocks(from: sectionJSON.content, facts: sectionJSON.facts, factsID: sectionJSON.factsID)
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
                contentID: chapterJSON.id,
                number: number,
                title: title,
                pillLabels: pillLabels,
                sections: sections
            )
        }
        return HandbookDocument(contentVersion: handbook.contentVersion, identityMigrations: handbook.identityMigrations, chapters: chapters)
    }

    /// Parse "Chapter 1 : The values and principles of the UK" into ("Chapter 1", "The values and principles of the UK")
    nonisolated private static func parseChapterTitle(_ raw: String, fallbackIndex: Int) -> (number: String, title: String) {
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
    nonisolated private static func buildBlocks(from items: [ContentItemJSON], facts: [String]?, factsID: String?) -> [ContentBlock] {
        var blocks: [ContentBlock] = []

        for item in items {
            switch item.type {
            case "paragraph":
                let raw = item.text ?? ""
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }

                if isBulletPrefixed(trimmed) {
                    blocks.append(ContentBlock(id: item.id, content: .bulletList([BulletItem(stripBulletPrefix(trimmed))])))
                } else {
                    blocks.append(ContentBlock(id: item.id, content: .paragraph(trimmed)))
                }

            case "bulletList":
                let bulletItems = (item.items ?? [])
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .map { BulletItem($0) }
                if !bulletItems.isEmpty {
                    blocks.append(ContentBlock(id: item.id, content: .bulletList(bulletItems)))
                }

            case "heading":
                let headingText = (item.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if headingText.isEmpty { continue }
                if (item.level ?? 3) >= 4 {
                    blocks.append(ContentBlock(id: item.id, content: .subheading2(headingText)))
                } else {
                    blocks.append(ContentBlock(id: item.id, content: .subheading(headingText)))
                }

            default:
                continue
            }
        }
        if let facts = facts {
            let cleaned = facts
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !cleaned.isEmpty {
                if let factsID { blocks.append(ContentBlock(id: factsID, content: .checkUnderstand(cleaned))) }
            }
        }

        return blocks
    }

    nonisolated private static func isBulletPrefixed(_ text: String) -> Bool {
        text.hasPrefix("·") || text.hasPrefix("•")
    }

    /// Strip a leading "·"/"•" marker plus any following whitespace (including non-breaking spaces).
    nonisolated private static func stripBulletPrefix(_ text: String) -> String {
        var s = text
        while s.hasPrefix("·") || s.hasPrefix("•") {
            s = String(s.dropFirst())
        }
        s = s.replacingOccurrences(of: "\u{00A0}", with: " ")
        return s.trimmingCharacters(in: .whitespaces)
    }
}
