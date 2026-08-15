import Foundation
import Observation
import OSLog
import SwiftData

// This is the single composition point for the persisted schema. Future model
// versions and SwiftData migration plans belong here, not in feature views.
enum AppPersistence {
    static let schema = Schema([
        ExamAttempt.self,
        ReadingProgress.self,
        Highlight.self,
        FlashcardReview.self,
        CustomFlashcard.self,
        QuestionAttemptRecord.self,
        FlashcardReviewEventRecord.self,
        LearningExamAttemptRecord.self,
        PerformanceSnapshotRecord.self
    ])

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

struct PersistenceIssue: Identifiable, Equatable {
    let id = UUID()
    let message: String
}

@MainActor
@Observable
final class PersistenceIssueCenter {
    private(set) var issue: PersistenceIssue?
    private let logger = Logger(subsystem: "Quizie", category: "Persistence")

    func report(_ error: Error, operation: String) {
        logger.error("\(operation, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        issue = PersistenceIssue(message: "\(operation) failed. \(error.localizedDescription)")
    }

    func dismiss() { issue = nil }
}

@MainActor
protocol ReadingProgressStore: AnyObject {
    func migrateLegacyRecords(using document: HandbookDocument) throws
    func fetchAll() throws -> [ReadingProgressSnapshot]
    func progress(for chapterID: String) throws -> ReadingProgressSnapshot?
    func startSession(chapterID: String, at date: Date) throws -> ReadingProgressSnapshot
    func endSession(chapterID: String, at date: Date) throws
    func update(chapterID: String, scrollOffset: Double, contentHeight: Double, viewportHeight: Double, at date: Date) throws
}

@MainActor
protocol HighlightStore: AnyObject {
    func migrateLegacyRecords(using document: HandbookDocument) throws
    func fetchAll() throws -> [HighlightSnapshot]
    func upsert(_ highlight: HighlightSnapshot) throws
    func delete(id: UUID) throws
}

@MainActor
final class SwiftDataReadingProgressStore: ReadingProgressStore {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    func migrateLegacyRecords(using document: HandbookDocument) throws {
        var changed = false
        for record in try context.fetch(FetchDescriptor<ReadingProgress>()) where record.chapterID.isEmpty {
            if let chapter = document.chapters.first(where: { $0.id == record.chapterId }) {
                record.chapterID = chapter.contentID
                changed = true
            }
        }
        if changed { try context.save() }
    }

    func fetchAll() throws -> [ReadingProgressSnapshot] {
        try context.fetch(FetchDescriptor<ReadingProgress>()).map(\.snapshot)
    }

    func progress(for chapterID: String) throws -> ReadingProgressSnapshot? {
        let descriptor = FetchDescriptor<ReadingProgress>(predicate: #Predicate { $0.chapterID == chapterID })
        return try context.fetch(descriptor).first?.snapshot
    }

    func startSession(chapterID: String, at date: Date) throws -> ReadingProgressSnapshot {
        let record = try record(for: chapterID)
        record.startReadingSession(at: date)
        try context.save()
        return record.snapshot
    }

    func endSession(chapterID: String, at date: Date) throws {
        guard let record = try fetchRecord(for: chapterID) else { return }
        record.endReadingSession(at: date)
        try context.save()
    }

    func update(chapterID: String, scrollOffset: Double, contentHeight: Double, viewportHeight: Double, at date: Date) throws {
        let record = try record(for: chapterID)
        record.updateProgress(scrollOffset: scrollOffset, contentHeight: contentHeight, viewportHeight: viewportHeight, at: date)
        try context.save()
    }

    private func fetchRecord(for chapterID: String) throws -> ReadingProgress? {
        let descriptor = FetchDescriptor<ReadingProgress>(predicate: #Predicate { $0.chapterID == chapterID })
        return try context.fetch(descriptor).first
    }

    private func record(for chapterID: String) throws -> ReadingProgress {
        if let existing = try fetchRecord(for: chapterID) { return existing }
        let record = ReadingProgress(chapterID: chapterID)
        context.insert(record)
        return record
    }
}

@MainActor
final class SwiftDataHighlightStore: HighlightStore {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    func migrateLegacyRecords(using document: HandbookDocument) throws {
        var changed = false
        for record in try context.fetch(FetchDescriptor<Highlight>()) where record.blockID.isEmpty {
            guard let chapter = document.chapters.first(where: { $0.id == record.chapterId }),
                  let section = chapter.sections.first(where: { $0.id == record.sectionId }),
                  section.blocks.indices.contains(record.blockIndex) else {
                context.delete(record); changed = true; continue
            }
            let candidate = section.blocks[record.blockIndex]
            let expectedPreview = String(candidate.plainText.prefix(80))
            guard !record.textPreview.isEmpty, expectedPreview == record.textPreview else {
                context.delete(record); changed = true; continue
            }
            record.chapterID = chapter.contentID
            record.sectionID = section.id
            record.blockID = candidate.id
            record.contentVersion = document.contentVersion
            changed = true
        }
        if changed { try context.save() }
    }

    func fetchAll() throws -> [HighlightSnapshot] {
        let descriptor = FetchDescriptor<Highlight>(sortBy: [SortDescriptor(\.createdDate, order: .reverse)])
        return try context.fetch(descriptor).map(\.snapshot)
    }

    func upsert(_ highlight: HighlightSnapshot) throws {
        let id = highlight.id
        let descriptor = FetchDescriptor<Highlight>(predicate: #Predicate { $0.id == id })
        if let record = try context.fetch(descriptor).first {
            record.apply(highlight)
        } else {
            context.insert(Highlight(snapshot: highlight))
        }
        try context.save()
    }

    func delete(id: UUID) throws {
        let descriptor = FetchDescriptor<Highlight>(predicate: #Predicate { $0.id == id })
        if let record = try context.fetch(descriptor).first { context.delete(record) }
        try context.save()
    }
}

@MainActor
final class InMemoryReadingProgressStore: ReadingProgressStore {
    private var records: [String: ReadingProgressSnapshot]
    init(records: [ReadingProgressSnapshot] = []) { self.records = Dictionary(uniqueKeysWithValues: records.map { ($0.chapterID, $0) }) }
    func migrateLegacyRecords(using document: HandbookDocument) throws {}
    func fetchAll() throws -> [ReadingProgressSnapshot] { Array(records.values) }
    func progress(for chapterID: String) throws -> ReadingProgressSnapshot? { records[chapterID] }
    func startSession(chapterID: String, at date: Date) throws -> ReadingProgressSnapshot {
        var value = records[chapterID] ?? ReadingProgressSnapshot(chapterID: chapterID, lastReadDate: date)
        value.sessionStartTime = value.sessionStartTime ?? date
        records[chapterID] = value
        return value
    }
    func endSession(chapterID: String, at date: Date) throws {
        guard var value = records[chapterID], let start = value.sessionStartTime else { return }
        let duration = date.timeIntervalSince(start)
        if duration > 2 { value.totalReadingTime += duration }
        value.sessionStartTime = nil
        records[chapterID] = value
    }
    func update(chapterID: String, scrollOffset: Double, contentHeight: Double, viewportHeight: Double, at date: Date) throws {
        var value = records[chapterID] ?? ReadingProgressSnapshot(chapterID: chapterID, lastReadDate: date)
        value.scrollOffset = scrollOffset
        value.contentHeight = contentHeight
        value.lastReadDate = date
        value.progress = min(max(scrollOffset / max(contentHeight - viewportHeight, 1), 0), 1)
        records[chapterID] = value
    }
}

@MainActor
final class InMemoryHighlightStore: HighlightStore {
    private var records: [UUID: HighlightSnapshot]
    init(records: [HighlightSnapshot] = []) { self.records = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) }) }
    func migrateLegacyRecords(using document: HandbookDocument) throws {}
    func fetchAll() throws -> [HighlightSnapshot] { records.values.sorted { $0.createdDate > $1.createdDate } }
    func upsert(_ highlight: HighlightSnapshot) throws { records[highlight.id] = highlight }
    func delete(id: UUID) throws { records[id] = nil }
}

@MainActor
@Observable
final class ReadingProgressLibrary {
    private let store: any ReadingProgressStore
    private let issues: PersistenceIssueCenter
    private(set) var records: [ReadingProgressSnapshot] = []

    init(store: any ReadingProgressStore, issues: PersistenceIssueCenter) {
        self.store = store; self.issues = issues; reload()
    }

    func reload() {
        do { records = try store.fetchAll() }
        catch { issues.report(error, operation: "Loading reading progress") }
    }
    func progress(for chapterID: String) -> ReadingProgressSnapshot? { records.first { $0.chapterID == chapterID } }
    @discardableResult func start(chapterID: String, at date: Date = Date()) -> ReadingProgressSnapshot? {
        do { let value = try store.startSession(chapterID: chapterID, at: date); reload(); return value }
        catch { issues.report(error, operation: "Starting reading session"); return nil }
    }
    func end(chapterID: String, at date: Date = Date()) {
        do { try store.endSession(chapterID: chapterID, at: date); reload() }
        catch { issues.report(error, operation: "Saving reading time") }
    }
    func update(chapterID: String, scrollOffset: Double, contentHeight: Double, viewportHeight: Double, at date: Date = Date()) {
        do { try store.update(chapterID: chapterID, scrollOffset: scrollOffset, contentHeight: contentHeight, viewportHeight: viewportHeight, at: date); reload() }
        catch { issues.report(error, operation: "Saving reading progress") }
    }
    func reconcile(document: HandbookDocument) {
        do { try store.migrateLegacyRecords(using: document); reload() }
        catch { issues.report(error, operation: "Migrating reading progress") }
    }
}

@MainActor
@Observable
final class HighlightLibrary {
    private let store: any HighlightStore
    private let issues: PersistenceIssueCenter
    private(set) var highlights: [HighlightSnapshot] = []
    private var activeContentVersion = 0
    init(store: any HighlightStore, issues: PersistenceIssueCenter) { self.store = store; self.issues = issues; reload() }
    func reload() {
        do { highlights = try store.fetchAll() }
        catch { issues.report(error, operation: "Loading highlights") }
    }
    func forChapter(_ chapterID: String) -> [HighlightSnapshot] { highlights.filter { $0.chapterID == chapterID } }
    func upsert(_ value: HighlightSnapshot) {
        let normalized = HighlightSnapshot(id: value.id, chapterID: value.chapterID, sectionID: value.sectionID, blockID: value.blockID, color: value.color, createdDate: value.createdDate, textPreview: value.textPreview, contentVersion: activeContentVersion, rangeLocation: value.rangeLocation, rangeLength: value.rangeLength)
        do { try store.upsert(normalized); reload() }
        catch { issues.report(error, operation: "Saving highlight") }
    }
    func delete(id: UUID) {
        do { try store.delete(id: id); reload() }
        catch { issues.report(error, operation: "Deleting highlight") }
    }

    /// Content identity policy: renamed IDs are rewritten; explicitly removed
    /// IDs and IDs absent from the new document are deleted. This deliberately
    /// favors dropping an orphan over attaching it to unrelated reordered text.
    func reconcile(document: HandbookDocument) {
        activeContentVersion = document.contentVersion
        do { try store.migrateLegacyRecords(using: document); reload() }
        catch { issues.report(error, operation: "Migrating highlights"); return }
        let migrations = document.identityMigrations
        for value in highlights where value.contentVersion != document.contentVersion {
            let chapterID = resolved(value.chapterID, through: migrations.renamedChapterIDs)
            let sectionID = resolved(value.sectionID, through: migrations.renamedSectionIDs)
            let blockID = resolved(value.blockID, through: migrations.renamedBlockIDs)
            if migrations.removedBlockIDs.contains(value.blockID) || !document.validBlockIDs.contains(blockID) {
                delete(id: value.id)
            } else {
                upsert(HighlightSnapshot(id: value.id, chapterID: chapterID, sectionID: sectionID, blockID: blockID, color: value.color, createdDate: value.createdDate, textPreview: value.textPreview, contentVersion: document.contentVersion, rangeLocation: value.rangeLocation, rangeLength: value.rangeLength))
            }
        }
    }

    private func resolved(_ original: String, through renames: [String: String]) -> String {
        var value = original
        var visited: Set<String> = []
        while let next = renames[value], visited.insert(value).inserted { value = next }
        return value
    }
}

@MainActor
struct PersistenceServices {
    let issues: PersistenceIssueCenter
    let attempts: AttemptHistory
    let progress: ReadingProgressLibrary
    let highlights: HighlightLibrary
    let flashcards: FlashcardMemory
    let learningEvents: LearningEventHistory

    init(container: ModelContainer) {
        let issues = PersistenceIssueCenter()
        self.issues = issues
        let attemptHistory = AttemptHistory(store: SwiftDataExamAttemptStore(context: container.mainContext), issues: issues)
        attempts = attemptHistory
        progress = ReadingProgressLibrary(store: SwiftDataReadingProgressStore(context: container.mainContext), issues: issues)
        highlights = HighlightLibrary(store: SwiftDataHighlightStore(context: container.mainContext), issues: issues)
        let eventHistory = LearningEventHistory(store: SwiftDataLearningEventStore(context: container.mainContext), issues: issues)
        learningEvents = eventHistory
        eventHistory.importLegacyExamAttempts(attemptHistory.attempts)
        flashcards = FlashcardMemory(store: SwiftDataFlashcardMemoryStore(context: container.mainContext), issues: issues, learningEvents: eventHistory)
    }

    init(attemptStore: any ExamAttemptStore, progressStore: any ReadingProgressStore, highlightStore: any HighlightStore) {
        self.init(
            attemptStore: attemptStore,
            progressStore: progressStore,
            highlightStore: highlightStore,
            flashcardStore: InMemoryFlashcardMemoryStore()
        )
    }

    init(
        attemptStore: any ExamAttemptStore,
        progressStore: any ReadingProgressStore,
        highlightStore: any HighlightStore,
        flashcardStore: any FlashcardMemoryStore
    ) {
        let issues = PersistenceIssueCenter()
        self.issues = issues
        let attemptHistory = AttemptHistory(store: attemptStore, issues: issues)
        attempts = attemptHistory
        let eventHistory = LearningEventHistory(store: InMemoryLearningEventStore(), issues: issues)
        learningEvents = eventHistory
        eventHistory.importLegacyExamAttempts(attemptHistory.attempts)
        progress = ReadingProgressLibrary(store: progressStore, issues: issues)
        highlights = HighlightLibrary(store: highlightStore, issues: issues)
        flashcards = FlashcardMemory(store: flashcardStore, issues: issues, learningEvents: eventHistory)
    }
}
