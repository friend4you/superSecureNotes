import Foundation

public enum NoteRepositoryError: Error, Equatable, Sendable {
    case notAuthenticated
    case noteNotFound
    case attachmentNotFound(String)
    case userNotFound(String)
    case shareNotFound(String)
    case alreadyShared(String)
    case conflict(String)
    case internalError(String)
    case corruptNote
    case databaseNotOpen
    case notSupported
    case validationError(String)
    case networkError
    case serverError(statusCode: Int, message: String?)
}

extension NoteRepositoryError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You’re not signed in."
        case .noteNotFound:
            return "Note not found."
        case let .attachmentNotFound(message),
             let .userNotFound(message),
             let .shareNotFound(message),
             let .alreadyShared(message),
             let .conflict(message),
             let .internalError(message),
             let .validationError(message):
            return message
        case .corruptNote:
            return "This note appears to be corrupted."
        case .databaseNotOpen:
            return "The local notes database is not open."
        case .notSupported:
            return "This operation is not supported."
        case .networkError:
            return "A network error occurred. Check your connection and try again."
        case let .serverError(_, message):
            return message ?? "Something went wrong on the server."
        }
    }
}
