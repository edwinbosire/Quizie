import Foundation
import SwiftData

/// SwiftData model to track reading progress for handbook chapters
@Model
final class ReadingProgress {
    var chapterId: Int
    var progress: Double // 0.0 to 1.0 (0% to 100%)
    var lastReadDate: Date
    var scrollOffset: Double // Absolute scroll position
    var contentHeight: Double // Total scrollable content height
    var totalReadingTime: TimeInterval // Total time spent reading in seconds
    var sessionStartTime: Date? // Track current session start
    
    init(
        chapterId: Int,
        progress: Double = 0.0,
        lastReadDate: Date = Date(),
        scrollOffset: Double = 0.0,
        contentHeight: Double = 0.0,
        totalReadingTime: TimeInterval = 0
    ) {
        self.chapterId = chapterId
        self.progress = progress
        self.lastReadDate = lastReadDate
        self.scrollOffset = scrollOffset
        self.contentHeight = contentHeight
        self.totalReadingTime = totalReadingTime
        self.sessionStartTime = nil
    }
    
    /// Update progress based on scroll position
    func updateProgress(scrollOffset: Double, contentHeight: Double, viewportHeight: Double) {
        self.scrollOffset = scrollOffset
        self.contentHeight = contentHeight
        self.lastReadDate = Date()
        
        // Calculate progress: how far through the scrollable content
        let maxScroll = max(contentHeight - viewportHeight, 1) // Avoid division by zero
        let rawProgress = scrollOffset / maxScroll
        
        // Clamp between 0 and 1
        self.progress = min(max(rawProgress, 0.0), 1.0)
    }
    
    /// Start tracking reading session
    func startReadingSession() {
        if sessionStartTime == nil {
            sessionStartTime = Date()
        }
    }
    
    /// End tracking reading session and add to total time
    func endReadingSession() {
        guard let startTime = sessionStartTime else { return }
        
        let sessionDuration = Date().timeIntervalSince(startTime)
        // Only count sessions longer than 2 seconds to avoid counting quick page views
        if sessionDuration > 2 {
            totalReadingTime += sessionDuration
        }
        sessionStartTime = nil
    }
    
    /// Get formatted reading time string
    var formattedReadingTime: String {
        let minutes = Int(totalReadingTime / 60)
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
    }
    
    /// Check if chapter is completed (read > 95%)
    var isCompleted: Bool {
        progress >= 0.95
    }
    
    /// Check if chapter has been started (read > 5%)
    var isStarted: Bool {
        progress > 0.05
    }
}

/// Extension to help with querying
extension ReadingProgress {
    static func fetchProgress(for chapterId: Int, in context: ModelContext) -> ReadingProgress? {
        let descriptor = FetchDescriptor<ReadingProgress>(
            predicate: #Predicate { $0.chapterId == chapterId }
        )
        return try? context.fetch(descriptor).first
    }
    
    static func getOrCreate(for chapterId: Int, in context: ModelContext) -> ReadingProgress {
        if let existing = fetchProgress(for: chapterId, in: context) {
            return existing
        }
        let new = ReadingProgress(chapterId: chapterId)
        context.insert(new)
        return new
    }
    
    /// Fetch all progress records
    static func fetchAllProgress(in context: ModelContext) -> [ReadingProgress] {
        let descriptor = FetchDescriptor<ReadingProgress>()
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Calculate overall handbook completion percentage
    static func overallCompletionPercentage(totalChapters: Int, in context: ModelContext) -> Double {
        let allProgress = fetchAllProgress(in: context)
        guard !allProgress.isEmpty else { return 0.0 }
        
        let totalProgress = allProgress.reduce(0.0) { $0 + $1.progress }
        return totalProgress / Double(totalChapters)
    }
    
    /// Calculate total reading time across all chapters
    static func totalReadingTime(in context: ModelContext) -> TimeInterval {
        let allProgress = fetchAllProgress(in: context)
        return allProgress.reduce(0.0) { $0 + $1.totalReadingTime }
    }
    
    /// Get most recently read chapter
    static func mostRecentlyRead(in context: ModelContext) -> ReadingProgress? {
        let allProgress = fetchAllProgress(in: context)
        return allProgress.max(by: { $0.lastReadDate < $1.lastReadDate })
    }
}
