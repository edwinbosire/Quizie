import Foundation
import SwiftData

struct ReadingProgressSnapshot: Identifiable, Equatable {
    var id: String { chapterID }
    let chapterID: String
    var progress: Double = 0
    var lastReadDate: Date = Date()
    var scrollOffset: Double = 0
    var contentHeight: Double = 0
    var totalReadingTime: TimeInterval = 0
    var sessionStartTime: Date?

    var formattedReadingTime: String {
        let minutes = Int(totalReadingTime / 60)
        return minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h \(minutes % 60)m"
    }
    var isCompleted: Bool { progress >= 0.95 }
    var isStarted: Bool { progress > 0.05 }
    var hasReadingActivity: Bool {
        progress > 0 || scrollOffset > 0 || totalReadingTime > 0
    }
}

/// Persistence record. Feature code consumes `ReadingProgressSnapshot` through
/// `ReadingProgressStore`, never this SwiftData type or a ModelContext.
@Model
final class ReadingProgress {
    /// Retained solely for lightweight migration from the pre-content-ID schema.
    var chapterId: Int = -1
    var chapterID: String = ""
    var progress: Double
    var lastReadDate: Date
    var scrollOffset: Double
    var contentHeight: Double
    var totalReadingTime: TimeInterval
    var sessionStartTime: Date?

    init(chapterID: String, progress: Double = 0, lastReadDate: Date = Date(), scrollOffset: Double = 0, contentHeight: Double = 0, totalReadingTime: TimeInterval = 0) {
        self.chapterID = chapterID
        self.progress = progress
        self.lastReadDate = lastReadDate
        self.scrollOffset = scrollOffset
        self.contentHeight = contentHeight
        self.totalReadingTime = totalReadingTime
    }

    var snapshot: ReadingProgressSnapshot {
        ReadingProgressSnapshot(chapterID: chapterID, progress: progress, lastReadDate: lastReadDate, scrollOffset: scrollOffset, contentHeight: contentHeight, totalReadingTime: totalReadingTime, sessionStartTime: sessionStartTime)
    }

    func updateProgress(scrollOffset: Double, contentHeight: Double, viewportHeight: Double, at date: Date = Date()) {
        self.scrollOffset = scrollOffset
        self.contentHeight = contentHeight
        lastReadDate = date
        progress = min(max(scrollOffset / max(contentHeight - viewportHeight, 1), 0), 1)
    }

    func startReadingSession(at date: Date = Date()) { sessionStartTime = sessionStartTime ?? date }
    func endReadingSession(at date: Date = Date()) {
        guard let start = sessionStartTime else { return }
        let duration = date.timeIntervalSince(start)
        if duration > 2 { totalReadingTime += duration }
        sessionStartTime = nil
    }
}
