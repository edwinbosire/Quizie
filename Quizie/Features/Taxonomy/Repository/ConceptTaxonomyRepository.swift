import Foundation

protocol ConceptTaxonomyRepository: Sendable {
    nonisolated func taxonomy() throws -> ConceptTaxonomy
}

struct BundleConceptTaxonomyRepository: ConceptTaxonomyRepository {
    let bundle: Bundle
    let resourceName: String

    init(bundle: Bundle = .main, resourceName: String = "concept-taxonomy") {
        self.bundle = bundle
        self.resourceName = resourceName
    }

    nonisolated func taxonomy() throws -> ConceptTaxonomy {
        let resource = "\(resourceName).json"
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw ContentRepositoryError.resourceNotFound(resource)
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ContentRepositoryError.unreadableResource(name: resource, reason: error.localizedDescription)
        }
        do {
            return try JSONDecoder().decode(ConceptTaxonomy.self, from: data)
        } catch {
            throw ContentRepositoryError.invalidContent(name: resource, reason: error.localizedDescription)
        }
    }
}
