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

protocol HandbookRepository {
    func chapters() throws -> [HandbookChapter]
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

    func chapters() throws -> [HandbookChapter] {
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

        let chapters: [HandbookChapter]
        do {
            chapters = try HandbookDocumentDecoder.decode(data)
        } catch {
            throw ContentRepositoryError.invalidContent(name: resource, reason: error.localizedDescription)
        }

        guard !chapters.isEmpty else {
            throw ContentRepositoryError.emptyContent(resource)
        }
        return chapters
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
    let allChapters: [HandbookChapter]

    init(_ chapters: [HandbookChapter]) {
        self.allChapters = chapters
    }

    func chapters() throws -> [HandbookChapter] {
        guard !allChapters.isEmpty else {
            throw ContentRepositoryError.emptyContent("in-memory handbook")
        }
        return allChapters
    }
}

@MainActor
@Observable
final class HandbookCatalog {
    private(set) var chapters: [HandbookChapter] = []
    private(set) var error: ContentRepositoryError?

    private let repository: any HandbookRepository

    init(repository: any HandbookRepository) {
        self.repository = repository
        reload()
    }

    func reload() {
        do {
            chapters = try repository.chapters()
            error = nil
        } catch let repositoryError as ContentRepositoryError {
            chapters = []
            error = repositoryError
        } catch {
            chapters = []
            self.error = .invalidContent(name: "handbook", reason: error.localizedDescription)
        }
    }
}

struct AppDependencies {
    let questions: any QuestionRepository
    let handbook: any HandbookRepository

    static func live(bundle: Bundle = .main) -> AppDependencies {
        AppDependencies(
            questions: BundleQuestionRepository(bundle: bundle),
            handbook: BundleHandbookRepository(bundle: bundle)
        )
    }
}
