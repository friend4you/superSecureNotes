import Foundation

public enum AuthRepositoryError: Error, Equatable, Sendable {
    case invalidCredentials
    case emailAlreadyExists
    case validationError(String)
    case notAuthenticated
    case networkError
    case serverError(statusCode: Int, message: String?)
}

extension AuthRepositoryError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password."
        case .emailAlreadyExists:
            return "Email is already registered."
        case let .validationError(message):
            return message
        case .notAuthenticated:
            return "You’re not signed in."
        case .networkError:
            return "A network error occurred. Check your connection and try again."
        case let .serverError(_, message):
            return message ?? "Something went wrong on the server."
        }
    }
}
