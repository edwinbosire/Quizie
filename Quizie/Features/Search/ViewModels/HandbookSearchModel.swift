import Foundation
import Observation

@MainActor
@Observable
final class HandbookSearchModel {
    private(set) var results: [HandbookSearchResult] = []
    private(set) var isSearching = false
    private(set) var error: ContentRepositoryError?

    private let service: any HandbookSearchServing
    private let debounce: Duration
    private var task: Task<Void, Never>?
    private var requestID = 0

    init(service: any HandbookSearchServing, debounce: Duration = .milliseconds(150)) {
        self.service = service
        self.debounce = debounce
    }

    func search(query: String) {
        requestID += 1
        let currentRequestID = requestID
        task?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            error = nil
            isSearching = false
            return
        }

        isSearching = true
        error = nil
        task = Task {
            do {
                try await Task.sleep(for: debounce)
                let found = try await service.search(query: trimmed)
                try Task.checkCancellation()
                guard requestID == currentRequestID else { return }
                results = found
                isSearching = false
            } catch is CancellationError {
                guard requestID == currentRequestID else { return }
                isSearching = false
            } catch let repositoryError as ContentRepositoryError {
                guard requestID == currentRequestID else { return }
                results = []
                error = repositoryError
                isSearching = false
            } catch {
                guard requestID == currentRequestID else { return }
                results = []
                self.error = .invalidContent(name: "handbook search", reason: error.localizedDescription)
                isSearching = false
            }
        }
    }

    func cancel() {
        requestID += 1
        task?.cancel()
        task = nil
        isSearching = false
    }
}
