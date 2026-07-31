import AuthFlowProtocol
import AuthRepositoryProtocol
import CryptoKit
import NoteRepositoryProtocol
import SecureCrypto
import VaultSessionProtocol
import XCTest

@MainActor
final class LogoutResetTests: XCTestCase {
    func testLogoutWipesAllPersistedState() async throws {
        let credentialStore = MockCredentialStore()
        try credentialStore.saveSetup(
            email: "user@example.com",
            refreshToken: "refresh-token",
            vaultHeader: Data([0x01, 0x02])
        )
        try credentialStore.setBioEnabled(true)
        try credentialStore.savePassword("secret")

        let authRepository = MockAuthRepository()
        _ = try await authRepository.login(
            LoginCredentials(email: "user@example.com", password: "secret")
        )

        let vaultSession = MockVaultSession()
        let notesIndexStore = MockNotesIndexStore()
        await vaultSession.establish(
            VaultSessionKeys(
                udk: SymmetricKey(size: .bits256),
                identityPrivateKey: Data(repeating: 0x01, count: 32)
            )
        )
        try await notesIndexStore.open(passphrase: Data([0x01]))

        await LogoutReset.perform(
            authRepository: authRepository,
            vaultSession: vaultSession,
            notesIndexStore: notesIndexStore,
            credentialStore: credentialStore
        )

        let currentSession = await authRepository.currentSession
        let establishedKeys = await vaultSession.establishedKeys
        let isOpen = await notesIndexStore.isOpen
        let closeCallCount = await notesIndexStore.closeCallCount
        XCTAssertNil(currentSession)
        XCTAssertNil(establishedKeys)
        XCTAssertFalse(isOpen)
        XCTAssertEqual(closeCallCount, 1)
        XCTAssertFalse(credentialStore.hasLocalSetup)
        XCTAssertNil(credentialStore.email())
        XCTAssertNil(credentialStore.refreshToken())
        XCTAssertNil(credentialStore.vaultHeader())
        XCTAssertFalse(credentialStore.bioEnabled())
        XCTAssertThrowsError(try credentialStore.loadPasswordWithBiometrics())
    }

    func testLogoutReturnsToFirstLaunchLogin() async throws {
        let credentialStore = MockCredentialStore()
        try credentialStore.saveSetup(
            email: "user@example.com",
            refreshToken: "refresh-token",
            vaultHeader: Data([0x01])
        )

        let authRepository = MockAuthRepository()
        _ = try await authRepository.login(
            LoginCredentials(email: "user@example.com", password: "secret")
        )

        await LogoutReset.perform(
            authRepository: authRepository,
            vaultSession: MockVaultSession(),
            notesIndexStore: MockNotesIndexStore(),
            credentialStore: credentialStore
        )

        XCTAssertFalse(credentialStore.hasLocalSetup)
    }
}
