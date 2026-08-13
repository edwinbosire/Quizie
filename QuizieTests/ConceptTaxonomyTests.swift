import Foundation
import Testing
@testable import BritReady__Life_in_UK_Test

struct ConceptTaxonomyTests {
    private let stableIDPattern = #"^[a-z0-9]+(?:-[a-z0-9]+)*(?:\.[a-z0-9]+(?:-[a-z0-9]+)*)*$"#

    @Test("The bundled concept taxonomy decodes through the production repository")
    func testTaxonomyDecodes() throws {
        let taxonomy = try loadTaxonomy()
        #expect(taxonomy.schemaVersion == 1)
        #expect(taxonomy.taxonomyVersion == "1.0.0")
        #expect(taxonomy.handbookVersion == "1.0.0")
        #expect(!taxonomy.generatedAt.isEmpty)
        #expect(taxonomy.concepts.count >= 200)
        #expect(!taxonomy.entities.isEmpty)
    }

    @Test("Concept IDs are unique")
    func testConceptIdsAreUnique() throws {
        let ids = try loadTaxonomy().concepts.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Entity IDs are unique")
    func testEntityIdsAreUnique() throws {
        let ids = try loadTaxonomy().entities.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Every parent reference resolves")
    func testAllParentReferencesExist() throws {
        let taxonomy = try loadTaxonomy()
        let ids = Set(taxonomy.concepts.map(\.id))
        for concept in taxonomy.concepts {
            if let parentId = concept.parentId {
                #expect(ids.contains(parentId), "Missing parent \(parentId) for \(concept.id)")
            }
        }
    }

    @Test("Every child reference resolves")
    func testAllChildReferencesExist() throws {
        let taxonomy = try loadTaxonomy()
        let ids = Set(taxonomy.concepts.map(\.id))
        for concept in taxonomy.concepts {
            #expect(Set(concept.childIds).count == concept.childIds.count, "Duplicate child on \(concept.id)")
            for childId in concept.childIds {
                #expect(ids.contains(childId), "Missing child \(childId) on \(concept.id)")
            }
        }
    }

    @Test("Parent and child relationships agree in both directions")
    func testParentChildRelationshipsAreSymmetric() throws {
        let taxonomy = try loadTaxonomy()
        let concepts = try conceptIndex(taxonomy)
        for concept in taxonomy.concepts {
            if let parentId = concept.parentId {
                let parent = try #require(concepts[parentId])
                #expect(parent.childIds.contains(concept.id), "\(parentId) does not list \(concept.id)")
            }
            for childId in concept.childIds {
                let child = try #require(concepts[childId])
                #expect(child.parentId == concept.id, "\(childId) does not point back to \(concept.id)")
            }
        }
    }

    @Test("Related concept references resolve and are symmetric")
    func testRelatedConceptReferencesExist() throws {
        let taxonomy = try loadTaxonomy()
        let concepts = try conceptIndex(taxonomy)
        for concept in taxonomy.concepts {
            for relatedId in concept.relatedConceptIds {
                let related = try #require(concepts[relatedId], "Missing related concept \(relatedId)")
                #expect(related.relatedConceptIds.contains(concept.id), "Relationship \(concept.id) ↔ \(relatedId) is asymmetric")
            }
        }
    }

    @Test("Concept and entity references resolve in both directions")
    func testEntityReferencesExist() throws {
        let taxonomy = try loadTaxonomy()
        let concepts = try conceptIndex(taxonomy)
        let entities = try entityIndex(taxonomy)
        for concept in taxonomy.concepts {
            for entityId in concept.entityIds {
                let entity = try #require(entities[entityId], "Missing entity \(entityId)")
                #expect(entity.relatedConceptIds.contains(concept.id), "Entity \(entityId) does not point back to \(concept.id)")
            }
        }
        for entity in taxonomy.entities {
            for conceptId in entity.relatedConceptIds {
                let concept = try #require(concepts[conceptId], "Missing concept \(conceptId) on \(entity.id)")
                #expect(concept.entityIds.contains(entity.id), "Concept \(conceptId) does not point back to \(entity.id)")
            }
        }
    }

    @Test("Every handbook chapter and section reference exists")
    func testHandbookReferencesExist() throws {
        let taxonomy = try loadTaxonomy()
        let handbook = try handbookIdentityIndex()
        for (ownerId, references) in allReferences(taxonomy) {
            for reference in references {
                #expect(handbook.chapterIds.contains(reference.chapterId), "Missing chapter \(reference.chapterId) on \(ownerId)")
                #expect(handbook.sectionChapters[reference.sectionId] == reference.chapterId, "Section \(reference.sectionId) is not in \(reference.chapterId) on \(ownerId)")
            }
        }
    }

    @Test("Every referenced handbook block exists in the referenced section")
    func testAllReferencedHandbookBlocksExist() throws {
        let taxonomy = try loadTaxonomy()
        let handbook = try handbookIdentityIndex()
        for (ownerId, references) in allReferences(taxonomy) {
            for reference in references {
                let validBlocks = try #require(handbook.sectionBlocks[reference.sectionId])
                #expect(Set(reference.blockIds).count == reference.blockIds.count, "Duplicate block ID on \(ownerId)")
                for blockId in reference.blockIds {
                    #expect(validBlocks.contains(blockId), "Missing block \(blockId) in \(reference.sectionId) on \(ownerId)")
                }
            }
        }
    }

    @Test("The concept hierarchy contains no cycles")
    func testNoConceptHierarchyCycles() throws {
        let taxonomy = try loadTaxonomy()
        let concepts = try conceptIndex(taxonomy)
        for concept in taxonomy.concepts {
            var visited = Set<String>()
            var currentId: String? = concept.id
            while let id = currentId {
                #expect(visited.insert(id).inserted, "Hierarchy cycle involving \(concept.id)")
                currentId = concepts[id]?.parentId
            }
        }
    }

    @Test("Importance weights and tiers use the documented ranges")
    func testImportanceWeightsAreValid() throws {
        for concept in try loadTaxonomy().concepts {
            let weight = concept.importance.weight
            #expect((0...1).contains(weight), "Invalid importance weight on \(concept.id)")
            switch concept.importance.tier {
            case .critical: #expect((0.9...1).contains(weight), "Invalid critical weight on \(concept.id)")
            case .high: #expect((0.7..<0.9).contains(weight), "Invalid high weight on \(concept.id)")
            case .medium: #expect((0.4..<0.7).contains(weight), "Invalid medium weight on \(concept.id)")
            case .low: #expect((0..<0.4).contains(weight), "Invalid low weight on \(concept.id)")
            }
        }
    }

    @Test("Concept and entity IDs use the stable lowercase format")
    func testStableIdFormat() throws {
        let taxonomy = try loadTaxonomy()
        let ids = taxonomy.concepts.map(\.id) + taxonomy.entities.map(\.id)
        for id in ids {
            #expect(id.range(of: stableIDPattern, options: .regularExpression) != nil, "Invalid stable ID \(id)")
        }
        for concept in taxonomy.concepts {
            #expect(concept.slug == concept.id.split(separator: ".").last.map(String.init), "Slug does not match \(concept.id)")
        }
    }

    @Test("Every non-root concept has exactly one parent")
    func testAllNonRootConceptsHaveParents() throws {
        let taxonomy = try loadTaxonomy()
        let rootIds = Set(taxonomy.rootConcepts.map(\.id))
        for concept in taxonomy.concepts where !rootIds.contains(concept.id) {
            #expect(concept.parentId != nil, "Non-root concept \(concept.id) has no parent")
        }
    }

    @Test("The 17 required domain roots have no parents")
    func testRootDomainsHaveNoParents() throws {
        let expected = Set([
            "uk-values-and-citizenship", "uk-identity-and-geography", "history", "science-and-invention",
            "arts-and-culture", "customs-and-traditions", "leisure-and-everyday-culture", "places-and-landmarks",
            "religion", "sport", "uk-society", "democracy-and-constitution", "government", "law-and-justice",
            "taxation-and-responsibilities", "international-relations", "community-and-civic-participation"
        ])
        let roots = try loadTaxonomy().rootConcepts
        #expect(Set(roots.map(\.id)) == expected)
        #expect(roots.allSatisfy { $0.parentId == nil })
    }

    @Test("Aliases are unique per concept and do not repeat canonical names")
    func testAliasesAreNormalized() throws {
        for concept in try loadTaxonomy().concepts {
            let normalized = concept.aliases.map { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) }
            #expect(Set(normalized).count == normalized.count, "Duplicate alias on \(concept.id)")
            #expect(!normalized.contains(concept.displayName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)), "Canonical name repeated as alias on \(concept.id)")
        }
    }

    @Test("Parents are serialized before their children")
    func testDeterministicParentBeforeChildOrdering() throws {
        let concepts = try loadTaxonomy().concepts
        let positions = Dictionary(uniqueKeysWithValues: concepts.enumerated().map { ($0.element.id, $0.offset) })
        for concept in concepts {
            if let parentId = concept.parentId {
                let parentPosition = try #require(positions[parentId])
                let childPosition = try #require(positions[concept.id])
                #expect(parentPosition < childPosition, "Parent follows child for \(concept.id)")
            }
        }
    }

    private func loadTaxonomy() throws -> ConceptTaxonomy {
        try BundleConceptTaxonomyRepository().taxonomy()
    }

    private func conceptIndex(_ taxonomy: ConceptTaxonomy) throws -> [String: TaxonomyConcept] {
        let grouped = Dictionary(grouping: taxonomy.concepts, by: \.id)
        #expect(grouped.values.allSatisfy { $0.count == 1 })
        return grouped.mapValues { $0[0] }
    }

    private func entityIndex(_ taxonomy: ConceptTaxonomy) throws -> [String: TaxonomyEntity] {
        let grouped = Dictionary(grouping: taxonomy.entities, by: \.id)
        #expect(grouped.values.allSatisfy { $0.count == 1 })
        return grouped.mapValues { $0[0] }
    }

    private func allReferences(_ taxonomy: ConceptTaxonomy) -> [(String, [TaxonomyHandbookReference])] {
        taxonomy.concepts.map { ($0.id, $0.handbookReferences) } + taxonomy.entities.map { ($0.id, $0.handbookReferences) }
    }

    private func handbookIdentityIndex() throws -> HandbookIdentityIndex {
        let url = try #require(Bundle.main.url(forResource: "handbook", withExtension: "json"))
        let root = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let chapters = try #require(root["chapters"] as? [[String: Any]])
        var chapterIds = Set<String>()
        var sectionChapters: [String: String] = [:]
        var sectionBlocks: [String: Set<String>] = [:]
        for chapter in chapters {
            let chapterId = try #require(chapter["id"] as? String)
            chapterIds.insert(chapterId)
            let sections = try #require(chapter["sections"] as? [[String: Any]])
            for section in sections {
                let sectionId = try #require(section["id"] as? String)
                sectionChapters[sectionId] = chapterId
                let content = try #require(section["content"] as? [[String: Any]])
                var blockIds = Set(content.compactMap { $0["id"] as? String })
                if let facts = section["facts"] as? [String], !facts.isEmpty, let factsId = section["facts_id"] as? String {
                    blockIds.insert(factsId)
                }
                sectionBlocks[sectionId] = blockIds
            }
        }
        return HandbookIdentityIndex(chapterIds: chapterIds, sectionChapters: sectionChapters, sectionBlocks: sectionBlocks)
    }
}

private struct HandbookIdentityIndex {
    let chapterIds: Set<String>
    let sectionChapters: [String: String]
    let sectionBlocks: [String: Set<String>]
}
