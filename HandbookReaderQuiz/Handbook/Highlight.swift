import Foundation
import SwiftUI
import SwiftData

// MARK: - Highlight Color

enum HighlightColor: String, CaseIterable, Codable, Identifiable {
    case yellow
    case blue
    case green
    case pink
    case orange

    var id: String { rawValue }

    var name: String { rawValue.capitalized }

    /// Solid color for icons and indicators
    var displayColor: Color {
        switch self {
        case .yellow: return Color(hex: "#F4D03F")
        case .blue:   return Color(hex: "#5DADE2")
        case .green:  return Color(hex: "#58D68D")
        case .pink:   return Color(hex: "#EC7063")
        case .orange: return Color(hex: "#F0B27A")
        }
    }

    /// Translucent background applied to highlighted blocks
    var backgroundColor: Color {
        switch self {
        case .yellow: return Color(hex: "#F4D03F").opacity(0.3)
        case .blue:   return Color(hex: "#5DADE2").opacity(0.25)
        case .green:  return Color(hex: "#58D68D").opacity(0.25)
        case .pink:   return Color(hex: "#EC7063").opacity(0.25)
        case .orange: return Color(hex: "#F0B27A").opacity(0.3)
        }
    }
}

// MARK: - Highlight Model

@Model
final class Highlight {
    var id: UUID
    var chapterId: Int
    var sectionId: String
    var blockIndex: Int
    var colorRaw: String
    var createdDate: Date
    var textPreview: String

    var highlightColor: HighlightColor {
        get { HighlightColor(rawValue: colorRaw) ?? .yellow }
        set { colorRaw = newValue.rawValue }
    }

    init(
        chapterId: Int,
        sectionId: String,
        blockIndex: Int,
        color: HighlightColor = .yellow,
        textPreview: String = ""
    ) {
        self.id = UUID()
        self.chapterId = chapterId
        self.sectionId = sectionId
        self.blockIndex = blockIndex
        self.colorRaw = color.rawValue
        self.createdDate = Date()
        self.textPreview = textPreview
    }
}

// MARK: - Fetch Helpers

extension Highlight {
    static func fetchForChapter(_ chapterId: Int, in context: ModelContext) -> [Highlight] {
        let descriptor = FetchDescriptor<Highlight>(
            predicate: #Predicate { $0.chapterId == chapterId },
            sortBy: [SortDescriptor(\.sectionId), SortDescriptor(\.blockIndex)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func fetchAll(in context: ModelContext) -> [Highlight] {
        let descriptor = FetchDescriptor<Highlight>(
            sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func find(chapterId: Int, sectionId: String, blockIndex: Int, in context: ModelContext) -> Highlight? {
        let descriptor = FetchDescriptor<Highlight>(
            predicate: #Predicate {
                $0.chapterId == chapterId &&
                $0.sectionId == sectionId &&
                $0.blockIndex == blockIndex
            }
        )
        return try? context.fetch(descriptor).first
    }
}
