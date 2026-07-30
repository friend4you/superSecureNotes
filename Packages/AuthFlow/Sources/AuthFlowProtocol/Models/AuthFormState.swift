import Foundation

public enum AuthFormState: Equatable, Sendable {
    case idle
    case loading
    case failure(AuthFlowError)
}

public enum AuthFlowError: Error, Equatable, Sendable {
    case invalidCredentials
    case emailAlreadyExists
    case validationError
    case vaultNotFound
    case vaultUnlockFailed
    case networkError
    case networkRequired
    case sessionExpired
    case unknown
}
