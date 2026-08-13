import Foundation

public enum VaultRepositoryError: Error, Equatable, Sendable {
    case notAuthenticated
    case headerNotFound
    case publicKeyNotFound
    case userNotFound(String)
    case validationError(String)
    case networkError
    case serverError(statusCode: Int, message: String?)
}

extension VaultRepositoryError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You’re not signed in."
        case .headerNotFound:
            return "Vault header not found."
        case .publicKeyNotFound:
            return "Public key not found."
        case let .userNotFound(message), let .validationError(message):
            return message
        case .networkError:
            return "A network error occurred. Check your connection and try again."
        case let .serverError(_, message):
            return message ?? "Something went wrong on the server."
        }
    }
}
