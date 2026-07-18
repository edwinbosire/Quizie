import Foundation

protocol HandbookRepository: Sendable {
    nonisolated func document() throws -> HandbookDocument
}

struct BundleHandbookRepository: HandbookRepository {
    let bundle: Bundle
    let resourceName: String

    init(bundle: Bundle = .main, resourceName: String = "handbook") {
        self.bundle = bundle
        self.resourceName = resourceName
    }

    nonisolated func document() throws -> HandbookDocument {
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

        let document: HandbookDocument
        do {
            document = try HandbookDocumentDecoder.decode(data)
        } catch {
            throw ContentRepositoryError.invalidContent(name: resource, reason: error.localizedDescription)
        }

        guard !document.chapters.isEmpty else {
            throw ContentRepositoryError.emptyContent(resource)
        }
        return document
    }
}

struct InMemoryHandbookRepository: HandbookRepository {
    let handbook: HandbookDocument

    init(_ chapters: [HandbookChapter]) {
        handbook = HandbookDocument(
            contentVersion: 1,
            identityMigrations: ContentIdentityMigrations(
                renamedChapterIDs: [:],
                renamedSectionIDs: [:],
                renamedBlockIDs: [:],
                removedBlockIDs: []
            ),
            chapters: chapters
        )
    }

    nonisolated func document() throws -> HandbookDocument {
        guard !handbook.chapters.isEmpty else {
            throw ContentRepositoryError.emptyContent("in-memory handbook")
        }
        return handbook
    }
}
