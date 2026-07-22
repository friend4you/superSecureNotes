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
        case .validationError:
            return .validationError
        case .networkError:
            return .networkError
        case .notAuthenticated, .serverError:
            return .unknown
        }
    }

    static func map(_ error: VaultRepositoryError) -> AuthFlowError {
        switch error {
        case .headerNotFound:
            return .vaultNotFound
        case .networkError:
            return .networkError
        case .notAuthenticated, .publicKeyNotFound, .validationError, .serverError:
            return .unknown
        }
    }
}
