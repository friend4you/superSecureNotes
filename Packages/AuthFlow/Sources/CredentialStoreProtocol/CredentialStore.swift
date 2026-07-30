import Foundation

public enum CredentialStoreError: Error, Equatable, Sendable {
    case itemNotFound
    case storageFailed
    case biometricsFailed
    case biometricsUnavailable
}

public protocol CredentialStore: Sendable {
    var hasLocalSetup: Bool { get }

    func markSetupComplete() throws
    func saveEmail(_ email: String) throws
    func email() -> String?
    func saveRefreshToken(_ token: String) throws
    func refreshToken() -> String?
    func saveVaultHeader(_ header: Data) throws
    func vaultHeader() -> Data?
    func bioEnabled() -> Bool
    func setBioEnabled(_ enabled: Bool) throws
    func savePassword(_ password: String) throws
    func loadPasswordWithBiometrics() throws -> String
    func saveSetup(email: String, refreshToken: String, vaultHeader: Data) throws
    func clearAll() throws
}
