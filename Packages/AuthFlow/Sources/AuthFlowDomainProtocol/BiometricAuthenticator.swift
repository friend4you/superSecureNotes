import Foundation

public enum BiometricAuthResult: Equatable, Sendable {
    case success
    case cancelled
    case failed
    case unavailable
}

public protocol BiometricAuthenticator: Sendable {
    func canEvaluateBiometrics() -> Bool
    func authenticate(reason: String) async -> BiometricAuthResult
}
