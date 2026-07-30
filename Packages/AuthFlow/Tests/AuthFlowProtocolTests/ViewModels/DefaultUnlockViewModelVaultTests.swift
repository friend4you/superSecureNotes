import AuthFlowProtocol
import AuthRepositoryProtocol
import XCTest

@MainActor
final class DefaultUnlockViewModelVaultTests: XCTestCase {
    func testRefreshSuccessStillRequiresPasswordForVault() async throws {
        let header = Data([0x01, 0x02])
        let credentialStore = try makeConfiguredCredentialStore(vaultHeader: header)
        let authRepository = MockAuthRepository()
        let vaultAuthenticator = MockVaultAuthenticator()
        let vaultSession = MockVaultSession()

        let viewModel = AuthFlowTestSupport.makeUnlockViewModel(
            credentialStore: credentialStore,
            authRepository: authRepository,
            vaultAuthenticator: vaultAuthenticator,
            vaultSession: vaultSession,
            networkReachability: MockNetworkReachability(isOnline: true)
        )
        viewModel.password = "secret"

        await viewModel.unlockWithPassword()

        let restoreCallCount = await authRepository.restoreSessionCallCount
        let establishedKeys = await vaultSession.establishedKeys

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(restoreCallCount, 1)
        XCTAssertEqual(vaultAuthenticator.unlockVaultCallCount, 1)
        XCTAssertEqual(vaultAuthenticator.lastUnlockPassword, "secret")
        XCTAssertEqual(vaultAuthenticator.lastUnlockHeaderData, header)
        XCTAssertNotNil(establishedKeys)
    }

    func testOfflineUnlockWithCachedHeader() async throws {
        let header = Data([0x0A, 0x0B, 0x0C])
        let credentialStore = try makeConfiguredCredentialStore(vaultHeader: header)
        let vaultAuthenticator = MockVaultAuthenticator()
        let vaultSession = MockVaultSession()

        let viewModel = AuthFlowTestSupport.makeUnlockViewModel(
            credentialStore: credentialStore,
            vaultAuthenticator: vaultAuthenticator,
            vaultSession: vaultSession,
            networkReachability: MockNetworkReachability(isOnline: false)
        )
        viewModel.password = "secret"

        await viewModel.unlockWithPassword()

        let establishedKeys = await vaultSession.establishedKeys

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(vaultAuthenticator.unlockVaultCallCount, 1)
        XCTAssertEqual(vaultAuthenticator.lastUnlockHeaderData, header)
        XCTAssertNotNil(establishedKeys)
    }

    func testStalePasswordAllowedOffline() async throws {
        let credentialStore = try makeConfiguredCredentialStore()
        let authRepository = MockAuthRepository()
        await authRepository.setRestoreError(.invalidCredentials)
        await authRepository.setLoginError(.invalidCredentials)
        let vaultSession = MockVaultSession()

        let viewModel = AuthFlowTestSupport.makeUnlockViewModel(
            credentialStore: credentialStore,
            authRepository: authRepository,
            vaultSession: vaultSession,
            networkReachability: MockNetworkReachability(isOnline: false)
        )
        viewModel.password = "stale-local-password"

        await viewModel.unlockWithPassword()

        let restoreCallCount = await authRepository.restoreSessionCallCount
        let loginCallCount = await authRepository.loginCallCount
        let establishedKeys = await vaultSession.establishedKeys

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(restoreCallCount, 0)
        XCTAssertEqual(loginCallCount, 0)
        XCTAssertNotNil(establishedKeys)
    }

    private func makeConfiguredCredentialStore(
        vaultHeader: Data = Data([0x01, 0x02])
    ) throws -> MockCredentialStore {
        let credentialStore = MockCredentialStore()
        try credentialStore.saveSetup(
            email: "user@example.com",
            refreshToken: "refresh-token",
            vaultHeader: vaultHeader
        )
        return credentialStore
    }
}

private extension MockAuthRepository {
    func setRestoreError(_ error: AuthRepositoryError) {
        restoreError = error
    }

    func setLoginError(_ error: AuthRepositoryError) {
        loginError = error
    }
}
