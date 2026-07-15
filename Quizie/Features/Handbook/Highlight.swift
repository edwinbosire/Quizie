import Foundation
import SwiftData
import SwiftUI

enum HighlightColor: String, CaseIterable, Codable, Identifiable {
    case yellow, blue, green, pink, orange
    var id: String { rawValue }
    var name: String { rawValue.capitalized }
    var displayColor: Color {
        switch self { case .yellow: Color(hex: "#F4D03F"); case .blue: Color(hex: "#5DADE2"); case .green: Color(hex: "#58D68D"); case .pink: Color(hex: "#EC7063"); case .orange: Color(hex: "#F0B27A") }
    }
    var backgroundColor: Color {
        switch self { case .yellow: displayColor.opacity(0.3); case .blue, .green, .pink: displayColor.opacity(0.25); case .orange: displayColor.opacity(0.3) }
    }
}

struct HighlightSnapshot: Identifiable, Hashable {
    let id: UUID
    let chapterID: String
    let sectionID: String
    let blockID: String
    var color: HighlightColor
    let createdDate: Date
    let textPreview: String
    let contentVersion: Int

    init(id: UUID = UUID(), chapterID: String, sectionID: String, blockID: String, color: HighlightColor = .yellow, createdDate: Date = Date(), textPreview: String = "", contentVersion: Int = 0) {
        self.id = id; self.chapterID = chapterID; self.sectionID = sectionID; self.blockID = blockID
        self.color = color; self.createdDate = createdDate; self.textPreview = textPreview; self.contentVersion = contentVersion
    }
    var chapterId: String { chapterID }
    var sectionId: String { sectionID }
    var highlightColor: HighlightColor { color }
}

/// Persistence record owned by `SwiftDataHighlightStore`.
@Model
final class Highlight {
    @Attribute(.unique) var id: UUID
    /// Legacy columns are retained only so existing stores can migrate safely.
    var chapterId: Int = -1
    var sectionId: String = ""
    var blockIndex: Int = -1
    var chapterID: String = ""
    var sectionID: String = ""
    var blockID: String = ""
    var colorRaw: String
    var createdDate: Date
    var textPreview: String
    var contentVersion: Int = 0

    init(snapshot: HighlightSnapshot) {
        id = snapshot.id; chapterID = snapshot.chapterID; sectionID = snapshot.sectionID; blockID = snapshot.blockID; sectionId = snapshot.sectionID
        colorRaw = snapshot.color.rawValue; createdDate = snapshot.createdDate; textPreview = snapshot.textPreview; contentVersion = snapshot.contentVersion
    }
    var snapshot: HighlightSnapshot { HighlightSnapshot(id: id, chapterID: chapterID, sectionID: sectionID, blockID: blockID, color: HighlightColor(rawValue: colorRaw) ?? .yellow, createdDate: createdDate, textPreview: textPreview, contentVersion: contentVersion) }
    func apply(_ value: HighlightSnapshot) {
        chapterID = value.chapterID; sectionID = value.sectionID; blockID = value.blockID; colorRaw = value.color.rawValue; textPreview = value.textPreview; contentVersion = value.contentVersion
    }
}
