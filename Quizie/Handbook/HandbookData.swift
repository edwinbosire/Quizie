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
    let data: [ChapterJSON]
}

private struct ChapterJSON: Codable {
    let title: String
    let content: [SectionJSON]
}

private struct SectionJSON: Codable {
    let title: String
    let content: String
}

// MARK: - Handbook Data (loaded from JSON)

struct HandbookData {

    static let chapters: [HandbookChapter] = loadChapters()

    private static func loadChapters() -> [HandbookChapter] {
        guard let url = Bundle.main.url(forResource: "handbook", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let handbook = try? JSONDecoder().decode(HandbookJSON.self, from: data) else {
            assertionFailure("Failed to load handbook.json from bundle")
            return []
        }

        return handbook.data.enumerated().map { index, chapterJSON in
            let sections = chapterJSON.content.enumerated().map { sectionIndex, sectionJSON in
                HandbookSection(
                    id: "c\(index + 1)s\(sectionIndex)",
                    title: sectionJSON.title,
                    blocks: HTMLContentParser.parse(sectionJSON.content)
                )
            }

            // Extract pill labels from section titles
            let pillLabels = sections.map { $0.title }

            // Extract chapter number and title from the JSON title
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
        // Try to split on " : " or ": "
        if let range = raw.range(of: #"\s*:\s*"#, options: .regularExpression) {
            let number = String(raw[raw.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let title = String(raw[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !number.isEmpty && !title.isEmpty {
                return (number, title)
            }
        }
        // Fallback: use the index to generate the chapter number
        return ("Chapter \(fallbackIndex)", raw)
    }
}

// MARK: - HTML Content Parser

/// Parses simplified HTML content from the handbook JSON into ContentBlock arrays.
private enum HTMLContentParser {

    static func parse(_ html: String) -> [ContentBlock] {
        var blocks: [ContentBlock] = []
        let scanner = Scanner(string: html)
        scanner.charactersToBeSkipped = nil

        while !scanner.isAtEnd {
            skipWhitespace(scanner)
            if scanner.isAtEnd { break }

            if scanString("<h3>", in: scanner) {
                // Check for "Check that you understand" heading
                if let heading = scanUntil("</h3>", in: scanner) {
                    let cleaned = stripTags(heading).trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleaned.lowercased().contains("check that you understand") {
                        // Collect following bullet items as checkUnderstand
                        let items = collectCheckUnderstandItems(scanner)
                        if !items.isEmpty {
                            blocks.append(.checkUnderstand(items))
                        }
                    } else {
                        blocks.append(.subheading(cleaned))
                    }
                }
            } else if scanString("<h4>", in: scanner) {
                if let heading = scanUntil("</h4>", in: scanner) {
                    blocks.append(.subheading2(stripTags(heading).trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            } else if scanString("<blockquote>", in: scanner) {
                if let content = scanUntil("</blockquote>", in: scanner) {
                    blocks.append(.blockquote(stripTags(content).trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            } else if scanString("<blockquote", in: scanner) {
                _ = scanUntil(">", in: scanner)
                if let content = scanUntil("</blockquote>", in: scanner) {
                    blocks.append(.blockquote(stripTags(content).trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            } else if scanString("<ul>", in: scanner) {
                let items = parseUnorderedList(scanner)
                if !items.isEmpty {
                    blocks.append(.bulletList(items))
                }
            } else if scanString("<ul ", in: scanner) {
                _ = scanUntil(">", in: scanner)
                let items = parseUnorderedList(scanner)
                if !items.isEmpty {
                    blocks.append(.bulletList(items))
                }
            } else if scanString("<table", in: scanner) {
                _ = scanUntil(">", in: scanner) // skip attributes
                let (headers, rows) = parseTable(scanner)
                if !headers.isEmpty || !rows.isEmpty {
                    blocks.append(.dataTable(headers: headers, rows: rows))
                }
            } else if scanString("<p", in: scanner) {
                // Skip attributes like id="3"
                _ = scanUntil(">", in: scanner)
                if let content = scanUntil("</p>", in: scanner) {
                    let plainText = stripTags(content).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !plainText.isEmpty {
                        // Check if this paragraph looks like a bullet list using · character
                        if plainText.hasPrefix("·") || plainText.hasPrefix("•") {
                            // This is a single bullet disguised as a paragraph; accumulate
                            var bulletTexts = [cleanBulletText(convertInlineFormatting(content))]
                            // Peek ahead for more bullet paragraphs
                            while peekForBulletParagraph(scanner) {
                                _ = scanString("<p", in: scanner) || scanString("<p>", in: scanner)
                                _ = scanUntil(">", in: scanner)
                                if let nextContent = scanUntil("</p>", in: scanner) {
                                    let nextText = convertInlineFormatting(nextContent).trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !nextText.isEmpty {
                                        bulletTexts.append(cleanBulletText(nextText))
                                    }
                                }
                            }
                            let items = bulletTexts.map { BulletItem($0) }
                            blocks.append(.bulletList(items))
                        } else {
                            blocks.append(.paragraph(convertInlineFormatting(content).trimmingCharacters(in: .whitespacesAndNewlines)))
                        }
                    }
                }
            } else {
                // Skip unknown tags or stray text
                scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)
            }
        }

        return blocks
    }

    // MARK: - List Parsing

    private static func parseUnorderedList(_ scanner: Scanner) -> [BulletItem] {
        var items: [BulletItem] = []
        // Scan until </ul>
        guard let listContent = scanUntil("</ul>", in: scanner) else { return items }

        let listScanner = Scanner(string: listContent)
        listScanner.charactersToBeSkipped = nil

        while !listScanner.isAtEnd {
            skipWhitespace(listScanner)
            if scanString("<li>", in: listScanner) {
                // <li> already consumed the closing >, read content directly
                if let itemContent = scanUntil("</li>", in: listScanner) {
                    let text = convertInlineFormatting(itemContent).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        items.append(BulletItem(text))
                    }
                }
            } else if scanString("<li ", in: listScanner) {
                // <li with attributes — skip to closing >
                _ = scanUntil(">", in: listScanner)
                if let itemContent = scanUntil("</li>", in: listScanner) {
                    let text = convertInlineFormatting(itemContent).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        items.append(BulletItem(text))
                    }
                }
            } else {
                if !listScanner.isAtEnd {
                    listScanner.currentIndex = listScanner.string.index(after: listScanner.currentIndex)
                }
            }
        }
        return items
    }

    // MARK: - Table Parsing

    private static func parseTable(_ scanner: Scanner) -> (headers: [String], rows: [[String]]) {
        guard let tableContent = scanUntil("</table>", in: scanner) else { return ([], []) }

        var headers: [String] = []
        var rows: [[String]] = []

        // Extract header row from <thead> or first <tr>
        let tableScanner = Scanner(string: tableContent)
        tableScanner.charactersToBeSkipped = nil

        while !tableScanner.isAtEnd {
            skipWhitespace(tableScanner)
            if scanString("<tr", in: tableScanner) {
                _ = scanUntil(">", in: tableScanner)
                if let rowContent = scanUntil("</tr>", in: tableScanner) {
                    let cells = extractCells(from: rowContent)
                    if headers.isEmpty && rowContent.contains("<th") {
                        headers = cells
                    } else if headers.isEmpty && rows.isEmpty {
                        // First row without <th> — treat as header
                        headers = cells
                    } else {
                        rows.append(cells)
                    }
                }
            } else {
                if !tableScanner.isAtEnd {
                    tableScanner.currentIndex = tableScanner.string.index(after: tableScanner.currentIndex)
                }
            }
        }

        return (headers, rows)
    }

    private static func extractCells(from rowHTML: String) -> [String] {
        var cells: [String] = []
        let cellScanner = Scanner(string: rowHTML)
        cellScanner.charactersToBeSkipped = nil

        while !cellScanner.isAtEnd {
            if scanString("<td", in: cellScanner) || scanString("<th", in: cellScanner) {
                _ = scanUntil(">", in: cellScanner)
                if let cellContent = scanUntil(cellScanner.string.contains("</th>") ? "</th>" : "</td>", in: cellScanner) {
                    cells.append(stripTags(cellContent).trimmingCharacters(in: .whitespacesAndNewlines))
                }
            } else {
                if !cellScanner.isAtEnd {
                    cellScanner.currentIndex = cellScanner.string.index(after: cellScanner.currentIndex)
                }
            }
        }
        return cells
    }

    // MARK: - Check Understand

    private static func collectCheckUnderstandItems(_ scanner: Scanner) -> [String] {
        // After "Check that you understand" heading, look for <p> with · bullets or <ul>
        var items: [String] = []
        let savedIndex = scanner.currentIndex

        skipWhitespace(scanner)

        // Try parsing a <ul> list
        if scanString("<ul>", in: scanner) || scanString("<ul ", in: scanner) {
            let bulletItems = parseUnorderedList(scanner)
            items = bulletItems.map { $0.text.raw }
        }

        // Also try parsing · bullet paragraphs
        if items.isEmpty {
            scanner.currentIndex = savedIndex
            skipWhitespace(scanner)
            while peekForBulletParagraph(scanner) {
                _ = scanString("<p", in: scanner) || scanString("<p>", in: scanner)
                _ = scanUntil(">", in: scanner)
                if let content = scanUntil("</p>", in: scanner) {
                    let text = cleanBulletText(stripTags(content).trimmingCharacters(in: .whitespacesAndNewlines))
                    if !text.isEmpty {
                        items.append(text)
                    }
                }
            }
        }

        return items
    }

    // MARK: - Helpers

    private static func skipWhitespace(_ scanner: Scanner) {
        _ = scanner.scanCharacters(from: .whitespacesAndNewlines)
    }

    @discardableResult
    private static func scanString(_ target: String, in scanner: Scanner) -> Bool {
        let remaining = scanner.string[scanner.currentIndex...]
        if remaining.hasPrefix(target) {
            scanner.currentIndex = scanner.string.index(scanner.currentIndex, offsetBy: target.count)
            return true
        }
        return false
    }

    private static func scanUntil(_ target: String, in scanner: Scanner) -> String? {
        let start = scanner.currentIndex
        if let range = scanner.string.range(of: target, range: scanner.currentIndex..<scanner.string.endIndex) {
            let result = String(scanner.string[start..<range.lowerBound])
            scanner.currentIndex = range.upperBound
            return result
        }
        // Target not found — consume rest
        let result = String(scanner.string[start...])
        scanner.currentIndex = scanner.string.endIndex
        return result.isEmpty ? nil : result
    }

    /// Strip all HTML tags from a string
    private static func stripTags(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
    }

    /// Convert <strong>/<b> tags to **markdown bold** for AttributedContent
    private static func convertInlineFormatting(_ html: String) -> String {
        var result = html
        // Convert <strong>text</strong> and <b>text</b> to **text**
        result = result.replacingOccurrences(
            of: #"<(?:strong|b)>(.*?)</(?:strong|b)>"#,
            with: "**$1**",
            options: .regularExpression
        )
        // Convert <em>text</em> and <i>text</i> to *text*
        result = result.replacingOccurrences(
            of: #"<(?:em|i)>(.*?)</(?:em|i)>"#,
            with: "*$1*",
            options: .regularExpression
        )
        return stripTags(result)
    }

    /// Check if next non-whitespace content is a bullet paragraph (starts with · or •)
    private static func peekForBulletParagraph(_ scanner: Scanner) -> Bool {
        let savedIndex = scanner.currentIndex
        let tempScanner = Scanner(string: String(scanner.string[scanner.currentIndex...]))
        tempScanner.charactersToBeSkipped = nil
        _ = tempScanner.scanCharacters(from: .whitespacesAndNewlines)

        let remaining = String(tempScanner.string[tempScanner.currentIndex...])
        // Check if it starts with <p> and the text content starts with · or •
        if remaining.hasPrefix("<p") {
            // Quick peek: find the text after the <p...> tag
            if let tagEnd = remaining.range(of: ">") {
                let afterTag = String(remaining[tagEnd.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let stripped = stripTags(afterTag).trimmingCharacters(in: .whitespacesAndNewlines)
                if stripped.hasPrefix("·") || stripped.hasPrefix("•") {
                    return true
                }
            }
        }
        scanner.currentIndex = savedIndex
        return false
    }

    /// Clean bullet text by removing leading · • and whitespace
    private static func cleanBulletText(_ text: String) -> String {
        var cleaned = text
        while cleaned.hasPrefix("·") || cleaned.hasPrefix("•") {
            cleaned = String(cleaned.dropFirst())
        }
        // Remove non-breaking spaces
        cleaned = cleaned.replacingOccurrences(of: "\u{00A0}", with: " ")
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
}
