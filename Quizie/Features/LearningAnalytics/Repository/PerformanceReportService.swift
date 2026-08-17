import Foundation
import Observation
import SwiftData

@Model
final class PerformanceSnapshotRecord {
    @Attribute(.unique) var key: String
    var generatedAt: Date
    var analyticsAlgorithmVersion: Int
    var taxonomyVersion: String
    var eventRevision: Int
    var reportData: Data

    init(generatedAt: Date, taxonomyVersion: String, eventRevision: Int, reportData: Data) {
        key = "learner-performance"
        self.generatedAt = generatedAt
        analyticsAlgorithmVersion = performanceAlgorithmVersion
        self.taxonomyVersion = taxonomyVersion
        self.eventRevision = eventRevision
        self.reportData = reportData
    }
}

@MainActor
protocol PerformanceSnapshotStore: AnyObject {
    func load(algorithmVersion: Int, taxonomyVersion: String) throws -> (report: LearnerPerformanceReport, eventRevision: Int)?
    func save(_ report: LearnerPerformanceReport, taxonomyVersion: String, eventRevision: Int) throws
}

@MainActor
final class SwiftDataPerformanceSnapshotStore: PerformanceSnapshotStore {
    private let context: ModelContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(context: ModelContext) { self.context = context }

    func load(algorithmVersion: Int, taxonomyVersion: String) throws -> (report: LearnerPerformanceReport, eventRevision: Int)? {
        let descriptor = FetchDescriptor<PerformanceSnapshotRecord>()
        guard let value = try context.fetch(descriptor).first,
              value.analyticsAlgorithmVersion == algorithmVersion,
              value.taxonomyVersion == taxonomyVersion else { return nil }
        return (try decoder.decode(LearnerPerformanceReport.self, from: value.reportData), value.eventRevision)
    }

    func save(_ report: LearnerPerformanceReport, taxonomyVersion: String, eventRevision: Int) throws {
        let data = try encoder.encode(report)
        let descriptor = FetchDescriptor<PerformanceSnapshotRecord>()
        if let existing = try context.fetch(descriptor).first {
            existing.generatedAt = report.generatedAt
            existing.analyticsAlgorithmVersion = performanceAlgorithmVersion
            existing.taxonomyVersion = taxonomyVersion
            existing.eventRevision = eventRevision
            existing.reportData = data
        } else {
            context.insert(PerformanceSnapshotRecord(generatedAt: report.generatedAt, taxonomyVersion: taxonomyVersion, eventRevision: eventRevision, reportData: data))
        }
        try context.save()
    }
}

@MainActor
final class InMemoryPerformanceSnapshotStore: PerformanceSnapshotStore {
    private var value: (LearnerPerformanceReport, String, Int, Int)?

    func load(algorithmVersion: Int, taxonomyVersion: String) throws -> (report: LearnerPerformanceReport, eventRevision: Int)? {
        guard let value, value.1 == taxonomyVersion, value.2 == algorithmVersion else { return nil }
        return (value.0, value.3)
    }

    func save(_ report: LearnerPerformanceReport, taxonomyVersion: String, eventRevision: Int) throws {
        value = (report, taxonomyVersion, performanceAlgorithmVersion, eventRevision)
    }
}

@MainActor
@Observable
final class PerformanceReportService {
    private(set) var report: LearnerPerformanceReport
    private(set) var lastError: Error?
    private let events: LearningEventHistory
    private let taxonomy: ConceptTaxonomy
    private let analyzer: any PerformanceAnalyzing
    private let cache: any PerformanceSnapshotStore
    private let staleInterval: TimeInterval = 6 * 60 * 60
    private var cachedEventRevision = -1

    init(events: LearningEventHistory, taxonomy: ConceptTaxonomy, analyzer: any PerformanceAnalyzing = PerformanceAnalyzer(), cache: any PerformanceSnapshotStore, referenceDate: Date = Date()) {
        self.events = events
        self.taxonomy = taxonomy
        self.analyzer = analyzer
        self.cache = cache
        if let cached = try? cache.load(algorithmVersion: performanceAlgorithmVersion, taxonomyVersion: taxonomy.taxonomyVersion) {
            report = cached.report
            cachedEventRevision = cached.eventRevision
        } else {
            report = .empty(at: referenceDate)
        }
        refresh(referenceDate: referenceDate)
    }

    func refresh(referenceDate: Date = Date(), force: Bool = false) {
        guard force || cachedEventRevision != events.revision || referenceDate.timeIntervalSince(report.generatedAt) >= staleInterval else { return }
        let rebuilt = analyzer.analyze(questionAttempts: events.questionAttempts, flashcardReviews: events.flashcardReviews, examAttempts: events.examAttempts, taxonomy: taxonomy, referenceDate: referenceDate)
        report = rebuilt
        cachedEventRevision = events.revision
        do {
            try cache.save(rebuilt, taxonomyVersion: taxonomy.taxonomyVersion, eventRevision: events.revision)
            lastError = nil
        } catch {
            lastError = error
        }
    }

    func practiceSummary(conceptIDs: [String]) -> PracticePerformanceSummary {
        let requested = Set(conceptIDs)
        guard !requested.isEmpty else { return .empty }
        let attempts = events.questionAttempts.filter { attempt in
            attempt.source == .sectionPractice && attempt.conceptWeights.contains { requested.contains($0.conceptID) }
        }
        guard !attempts.isEmpty else { return .empty }
        let correctCount = attempts.count(where: \.wasCorrect)
        let accuracy = Double(correctCount) / Double(attempts.count)
        let recent = attempts.suffix(5)
        let earlier = attempts.dropLast(recent.count).suffix(5)
        let trend: PerformanceTrend
        if earlier.count >= 2, recent.count >= 2 {
            let recentAccuracy = Double(recent.count(where: \.wasCorrect)) / Double(recent.count)
            let earlierAccuracy = Double(earlier.count(where: \.wasCorrect)) / Double(earlier.count)
            trend = recentAccuracy - earlierAccuracy >= 0.10 ? .improving : earlierAccuracy - recentAccuracy >= 0.10 ? .declining : .stable
        } else {
            trend = .unknown
        }
        return PracticePerformanceSummary(answeredCount: attempts.count, correctCount: correctCount, accuracy: accuracy, trend: trend)
    }
}
