import Foundation

nonisolated struct TaxonomyTagResolver: Sendable {
    static let empty = TaxonomyTagResolver()

    let taxonomyVersion: String
    private let conceptsByID: [String: TaxonomyConcept]
    private let entitiesByID: [String: TaxonomyEntity]
    private let conceptIDsByBlockID: [String: [String]]
    private let conceptIDsBySectionID: [String: [String]]
    private let entityIDsByBlockID: [String: [String]]

    init() {
        taxonomyVersion = ""
        conceptsByID = [:]
        entitiesByID = [:]
        conceptIDsByBlockID = [:]
        conceptIDsBySectionID = [:]
        entityIDsByBlockID = [:]
    }

    init(taxonomy: ConceptTaxonomy) {
        taxonomyVersion = taxonomy.taxonomyVersion
        conceptsByID = taxonomy.conceptsByID
        entitiesByID = taxonomy.entitiesByID
        conceptIDsByBlockID = Self.referencesByBlock(taxonomy.concepts)
        conceptIDsBySectionID = Self.referencesBySection(taxonomy.concepts)
        entityIDsByBlockID = Self.referencesByBlock(taxonomy.entities)
    }

    func tags(forBlockIDs blockIDs: [String]) -> ContentTaxonomyTags {
        let conceptIDs = orderedConceptIDs(mostSpecific(blockIDs.flatMap { conceptIDsByBlockID[$0] ?? [] }))
        let entityIDs = unique(blockIDs.flatMap { entityIDsByBlockID[$0] ?? [] })
        return ContentTaxonomyTags(primaryConceptId: conceptIDs.first, conceptIds: Array(conceptIDs.prefix(3)), entityIds: entityIDs)
    }

    func conceptIDs(forSectionID sectionID: String) -> [String] {
        orderedConceptIDs(unique(conceptIDsBySectionID[sectionID] ?? []))
    }

    func tags(for text: String, chapter: Int?) -> ContentTaxonomyTags {
        let normalizedText = Self.normalized(text)
        let matchingConceptIDs = conceptsByID.values.compactMap { concept -> String? in
            let terms = [concept.displayName] + concept.aliases + (concept.taggingHints?.includeTerms ?? [])
            return terms.contains { Self.contains(term: $0, in: normalizedText) } ? concept.id : nil
        }
        let conceptIDs = mostSpecific(matchingConceptIDs).sorted()
        let matchingEntityIDs = entitiesByID.values.compactMap { entity -> String? in
            ([entity.displayName] + entity.aliases).contains { Self.contains(term: $0, in: normalizedText) } ? entity.id : nil
        }.sorted()
        let entityConceptIDs = mostSpecific(matchingEntityIDs.flatMap { entitiesByID[$0]?.relatedConceptIds ?? [] }).sorted()
        let resolvedConceptIDs = unique(conceptIDs + entityConceptIDs)
        if !resolvedConceptIDs.isEmpty {
            return ContentTaxonomyTags(primaryConceptId: resolvedConceptIDs.first, conceptIds: Array(resolvedConceptIDs.prefix(3)), entityIds: matchingEntityIDs)
        }
        let fallback = chapter.flatMap(Self.chapterFallback) ?? "uk-values-and-citizenship"
        return ContentTaxonomyTags(primaryConceptId: fallback, conceptIds: [fallback], entityIds: matchingEntityIDs)
    }

    func conceptPath(for conceptID: String) -> [TaxonomyConcept] {
        guard let concept = conceptsByID[conceptID] else { return [] }
        var path = [concept]
        var parentID = concept.parentId
        while let currentID = parentID, let parent = conceptsByID[currentID] {
            path.append(parent)
            parentID = parent.parentId
        }
        return path.reversed()
    }

    func handbookReferences(for conceptID: String) -> [TaxonomyHandbookReference] {
        conceptsByID[conceptID]?.handbookReferences ?? []
    }

    private func mostSpecific(_ values: [String]) -> [String] {
        let conceptIDs = unique(values).filter { conceptsByID[$0] != nil }
        return conceptIDs.filter { candidate in
            !conceptIDs.contains { other in candidate != other && isAncestor(candidate, of: other) }
        }
    }

    private func isAncestor(_ ancestorID: String, of descendantID: String) -> Bool {
        var parentID = conceptsByID[descendantID]?.parentId
        while let currentID = parentID {
            if currentID == ancestorID { return true }
            parentID = conceptsByID[currentID]?.parentId
        }
        return false
    }

    private func orderedConceptIDs(_ values: [String]) -> [String] {
        values.sorted { left, right in
            let leftConcept = conceptsByID[left]
            let rightConcept = conceptsByID[right]
            if leftConcept?.importance.weight != rightConcept?.importance.weight { return leftConcept?.importance.weight ?? 0 > rightConcept?.importance.weight ?? 0 }
            if left.count != right.count { return left.count > right.count }
            return left < right
        }
    }

    private func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private static func referencesByBlock<T>(_ values: [T]) -> [String: [String]] where T: TaxonomyReferencing {
        var result: [String: [String]] = [:]
        for value in values {
            for blockID in value.handbookReferences.flatMap(\.blockIds) {
                result[blockID, default: []].append(value.id)
            }
        }
        return result
    }

    private static func referencesBySection<T>(_ values: [T]) -> [String: [String]] where T: TaxonomyReferencing {
        var result: [String: [String]] = [:]
        for value in values {
            for reference in value.handbookReferences {
                result[reference.sectionId, default: []].append(value.id)
            }
        }
        return result
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_GB"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func contains(term: String, in normalizedText: String) -> Bool {
        let normalizedTerm = normalized(term)
        guard normalizedTerm.count >= 4 else { return false }
        return " \(normalizedText) ".contains(" \(normalizedTerm) ")
    }

    private static func chapterFallback(_ chapter: Int) -> String? {
        switch chapter {
        case 1: return "uk-values-and-citizenship"
        case 2: return "uk-identity-and-geography"
        case 3: return "history"
        case 4: return "uk-society"
        case 5: return "government"
        default: return nil
        }
    }
}

private nonisolated protocol TaxonomyReferencing {
    var id: String { get }
    var handbookReferences: [TaxonomyHandbookReference] { get }
}

nonisolated extension TaxonomyConcept: TaxonomyReferencing {}
nonisolated extension TaxonomyEntity: TaxonomyReferencing {}
