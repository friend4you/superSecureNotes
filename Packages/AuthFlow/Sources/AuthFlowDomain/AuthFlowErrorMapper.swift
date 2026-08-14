import AuthFlowDomainProtocol
import AuthRepositoryProtocol
import Foundation
import VaultRepositoryProtocol

enum AuthFlowErrorMapper {
    static func map(_ error: AuthRepositoryError) -> AuthFlowError {
        switch error {
        case .invalidCredentials:
            return .invalidCredentials
        case .emailAlreadyExists:
            return .emailAlreadyExists
        case let .validationError(message):
            return .validationError(message)
        case .networkError:
            return .networkError
        case let .serverError(_, message):
            return message.map(AuthFlowError.validationError) ?? .unknown
        case .notAuthenticated:
            return .unknown
        }
    }

    static func map(_ error: VaultRepositoryError) -> AuthFlowError {
        switch error {
        case .headerNotFound:
            return .vaultNotFound
        case .networkError:
            return .networkError
        case let .validationError(message):
            return .validationError(message)
        case let .userNotFound(message):
            return .validationError(message)
        case let .serverError(_, message):
            return message.map(AuthFlowError.validationError) ?? .unknown
        case .notAuthenticated, .publicKeyNotFound:
            return .unknown
        }
    }

    static func mapUnlockAuthError(_ error: AuthRepositoryError) -> AuthFlowError {
        switch error {
        case .invalidCredentials:
            return .sessionExpired
        case .networkError:
            return .networkError
        case let .validationError(message):
            return .validationError(message)
        case let .serverError(_, message):
            return message.map(AuthFlowError.validationError) ?? .unknown
        case .emailAlreadyExists, .notAuthenticated:
            return .unknown
        }
    }
}
