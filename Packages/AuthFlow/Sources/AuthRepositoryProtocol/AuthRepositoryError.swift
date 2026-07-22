import Foundation

public enum AuthRepositoryError: Error, Equatable, Sendable {
    case invalidCredentials
    case emailAlreadyExists
    case validationError(String)
    case notAuthenticated
    case networkError
    case serverError(statusCode: Int)
}
