import Foundation
import Observation

enum ContentRepositoryError: Error, Equatable, LocalizedError {
    case resourceNotFound(String)
    case unreadableResource(name: String, reason: String)
    case invalidContent(name: String, reason: String)
    case emptyContent(String)

    var errorDescription: String? {
        switch self {
        case .resourceNotFound(let name):
            return "The bundled content resource ‘\(name)’ could not be found."
        case .unreadableResource(let name, let reason):
            return "The content resource ‘\(name)’ could not be read: \(reason)"
        case .invalidContent(let name, let reason):
            return "The content resource ‘\(name)’ is invalid: \(reason)"
        case .emptyContent(let name):
            return "The content resource ‘\(name)’ does not contain any usable content."
        }
    }
}

protocol QuestionRepository {
    func questions(count: Int, seed: String?) throws -> [QuizQuestion]
}

protocol HandbookRepository: Sendable {
    nonisolated func document() throws -> HandbookDocument
}

struct BundleQuestionRepository: QuestionRepository {
    let bundle: Bundle
    let resourceName: String

    init(bundle: Bundle = .main, resourceName: String = "questions") {
        self.bundle = bundle
        self.resourceName = resourceName
    }

    func questions(count: Int, seed: String?) throws -> [QuizQuestion] {
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

        let allQuestions: [QuizQuestion]
        do {
            allQuestions = try QuestionDocumentDecoder.decode(data)
        } catch {
            throw ContentRepositoryError.invalidContent(name: resource, reason: error.localizedDescription)
        }

        guard !allQuestions.isEmpty else {
            throw ContentRepositoryError.emptyContent(resource)
        }
        return QuestionSelector.select(from: allQuestions, count: count, seed: seed)
    }
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

struct InMemoryQuestionRepository: QuestionRepository {
    let allQuestions: [QuizQuestion]

    init(_ questions: [QuizQuestion]) {
        self.allQuestions = questions
    }

    func questions(count: Int, seed: String?) throws -> [QuizQuestion] {
        guard !allQuestions.isEmpty else {
            throw ContentRepositoryError.emptyContent("in-memory questions")
        }
        return QuestionSelector.select(from: allQuestions, count: count, seed: seed)
    }
}

struct InMemoryHandbookRepository: HandbookRepository {
    let handbook: HandbookDocument

    init(_ chapters: [HandbookChapter]) {
        self.handbook = HandbookDocument(contentVersion: 1, identityMigrations: ContentIdentityMigrations(renamedChapterIDs: [:], renamedSectionIDs: [:], renamedBlockIDs: [:], removedBlockIDs: []), chapters: chapters)
    }

    nonisolated func document() throws -> HandbookDocument {
        guard !handbook.chapters.isEmpty else {
            throw ContentRepositoryError.emptyContent("in-memory handbook")
        }
        return handbook
    }
}

@MainActor
@Observable
final class HandbookCatalog {
    private(set) var document: HandbookDocument?
    private(set) var chapters: [HandbookChapter] = []
    private(set) var contentVersion = 0
    private(set) var identityMigrations = ContentIdentityMigrations(renamedChapterIDs: [:], renamedSectionIDs: [:], renamedBlockIDs: [:], removedBlockIDs: [])
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
