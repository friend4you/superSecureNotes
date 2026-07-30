import AuthFlowProtocol
import AuthRepositoryProtocol
import CryptoKit
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
        await vaultSession.establish(
            VaultSessionKeys(
                udk: SymmetricKey(size: .bits256),
                identityPrivateKey: Data(repeating: 0x01, count: 32)
            )
        )

        await LogoutReset.perform(
            authRepository: authRepository,
            vaultSession: vaultSession,
            credentialStore: credentialStore
        )

        let currentSession = await authRepository.currentSession
        let establishedKeys = await vaultSession.establishedKeys
        XCTAssertNil(currentSession)
        XCTAssertNil(establishedKeys)
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
            credentialStore: credentialStore
        )

        XCTAssertFalse(credentialStore.hasLocalSetup)
    }
}
