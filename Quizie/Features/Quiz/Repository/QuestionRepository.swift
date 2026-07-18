import Foundation

protocol QuestionRepository {
    func questions(count: Int, seed: String?) throws -> [QuizQuestion]
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
