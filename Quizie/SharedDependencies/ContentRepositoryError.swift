import Foundation

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
