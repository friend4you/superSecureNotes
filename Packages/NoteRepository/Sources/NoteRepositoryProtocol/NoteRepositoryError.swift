import Foundation

public enum NoteRepositoryError: Error, Equatable, Sendable {
    case notAuthenticated
    case noteNotFound
    case corruptNote
    case databaseNotOpen
    case notSupported
    case validationError(String)
    case networkError
    case serverError(statusCode: Int)
}
