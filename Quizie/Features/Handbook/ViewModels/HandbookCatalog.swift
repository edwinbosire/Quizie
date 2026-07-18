import Foundation
import Observation

@MainActor
@Observable
final class HandbookCatalog {
    private(set) var document: HandbookDocument?
    private(set) var chapters: [HandbookChapter] = []
    private(set) var contentVersion = 0
    private(set) var identityMigrations = ContentIdentityMigrations(
        renamedChapterIDs: [:],
        renamedSectionIDs: [:],
        renamedBlockIDs: [:],
        removedBlockIDs: []
    )
    private(set) var error: ContentRepositoryError?

    private let repository: any HandbookRepository

    init(repository: any HandbookRepository) {
        self.repository = repository
        reload()
    }

    func reload() {
        do {
            let document = try repository.document()
            self.document = document
            chapters = document.chapters
            contentVersion = document.contentVersion
            identityMigrations = document.identityMigrations
            error = nil
        } catch let repositoryError as ContentRepositoryError {
            chapters = []
            document = nil
            error = repositoryError
        } catch {
            chapters = []
            document = nil
            self.error = .invalidContent(name: "handbook", reason: error.localizedDescription)
        }
    }
}
