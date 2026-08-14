import Foundation

public enum AuthFlowError: Error, Equatable, Sendable {
    case invalidCredentials
    case emailAlreadyExists
    case validationError(String?)
    case vaultNotFound
    case vaultUnlockFailed
    case networkError
    case networkRequired
    case sessionExpired
    case unknown
}
