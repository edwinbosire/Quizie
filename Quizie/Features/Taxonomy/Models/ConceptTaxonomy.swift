import Foundation

nonisolated struct ContentTaxonomyTags: Codable, Equatable, Hashable, Sendable {
    let primaryConceptId: String?
    let conceptIds: [String]
    let entityIds: [String]

    init(primaryConceptId: String? = nil, conceptIds: [String] = [], entityIds: [String] = []) {
        let concepts = Self.unique(conceptIds)
        self.primaryConceptId = primaryConceptId ?? concepts.first
        self.conceptIds = self.primaryConceptId.map { concepts.contains($0) ? concepts : [$0] + concepts } ?? concepts
        self.entityIds = Self.unique(entityIds)
    }

    static let empty = ContentTaxonomyTags()

    var isEmpty: Bool { conceptIds.isEmpty && entityIds.isEmpty }

    func merging(_ other: ContentTaxonomyTags) -> ContentTaxonomyTags {
        ContentTaxonomyTags(primaryConceptId: primaryConceptId ?? other.primaryConceptId, conceptIds: conceptIds + other.conceptIds, entityIds: entityIds + other.entityIds)
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}

nonisolated struct ConceptTaxonomy: Codable, Sendable {
    let schemaVersion: Int
    let taxonomyVersion: String
    let handbookVersion: String
    let generatedAt: String
    let concepts: [TaxonomyConcept]
    let entities: [TaxonomyEntity]

    var conceptsByID: [String: TaxonomyConcept] {
        Dictionary(uniqueKeysWithValues: concepts.map { ($0.id, $0) })
    }

    var entitiesByID: [String: TaxonomyEntity] {
        Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0) })
    }

    var rootConcepts: [TaxonomyConcept] {
        concepts.filter { $0.parentId == nil }
    }
}

nonisolated struct TaxonomyConcept: Codable, Identifiable, Sendable {
    let id: String
    let slug: String
    let displayName: String
    let description: String
    let domainId: String
    let parentId: String?
    let childIds: [String]
    let aliases: [String]
    let relatedConceptIds: [String]
    let handbookReferences: [TaxonomyHandbookReference]
    let entityIds: [String]
    let importance: ConceptImportance
    let taggingHints: ConceptTaggingHints?
}

nonisolated struct TaxonomyEntity: Codable, Identifiable, Sendable {
    let id: String
    let type: TaxonomyEntityType
    let displayName: String
    let aliases: [String]
    let relatedConceptIds: [String]
    let handbookReferences: [TaxonomyHandbookReference]
}

nonisolated enum TaxonomyEntityType: String, Codable, CaseIterable, Sendable {
    case person
    case date
    case event
    case place
    case institution
    case law
    case document
    case organisation
    case invention
    case work
}

nonisolated struct TaxonomyHandbookReference: Codable, Hashable, Sendable {
    let chapterId: String
    let sectionId: String
    let blockIds: [String]
}

nonisolated struct ConceptImportance: Codable, Sendable {
    let weight: Double
    let tier: ConceptImportanceTier
    let rationale: String
}

nonisolated enum ConceptImportanceTier: String, Codable, CaseIterable, Sendable {
    case critical
    case high
    case medium
    case low
}

nonisolated struct ConceptTaggingHints: Codable, Sendable {
    let includeTerms: [String]
    let excludeTerms: [String]
}
