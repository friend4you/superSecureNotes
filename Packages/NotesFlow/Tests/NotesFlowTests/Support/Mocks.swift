import CredentialStoreProtocol
import Foundation

enum NotesFlowTestMocks {
    static func credentialStore() -> MockCredentialStore {
        MockCredentialStore()
    }
}

final class MockCredentialStore: CredentialStore, @unchecked Sendable {
    var hasLocalSetup = false

    func markSetupComplete() throws { hasLocalSetup = true }
    func saveEmail(_ email: String) throws {}
    func email() -> String? { nil }
    func saveRefreshToken(_ token: String) throws {}
    func refreshToken() -> String? { nil }
    func saveVaultHeader(_ header: Data) throws {}
    func vaultHeader() -> Data? { nil }
    func bioEnabled() -> Bool { false }
    func setBioEnabled(_ enabled: Bool) throws {}
    func savePassword(_ password: String) throws {}
    func loadPasswordWithBiometrics() throws -> String { throw CredentialStoreError.itemNotFound }
    func saveSetup(email: String, refreshToken: String, vaultHeader: Data) throws {}
    func clearAll() throws { hasLocalSetup = false }
}
