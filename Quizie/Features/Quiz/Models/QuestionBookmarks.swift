import Foundation

enum QuestionBookmarks {
    static let storageKey = "bookmarkedQuestions"

    static func ids(from data: Data) -> Set<String> {
        guard !data.isEmpty else { return [] }
        if let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            return ids
        }
        if let ids = try? JSONDecoder().decode([String].self, from: data) {
            return Set(ids)
        }
        return []
    }

    static func data(for ids: Set<String>) -> Data {
        (try? JSONEncoder().encode(ids.sorted())) ?? Data()
    }
}
