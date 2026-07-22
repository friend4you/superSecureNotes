import Foundation

public enum VaultRepositoryError: Error, Equatable, Sendable {
    case notAuthenticated
    case headerNotFound
    case publicKeyNotFound
    case validationError(String)
    case networkError
    case serverError(statusCode: Int)
}
