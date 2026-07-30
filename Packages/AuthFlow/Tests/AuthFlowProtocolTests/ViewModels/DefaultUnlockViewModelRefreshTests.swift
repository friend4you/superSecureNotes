import AuthFlowProtocol
import AuthRepositoryProtocol
import XCTest

@MainActor
final class DefaultUnlockViewModelRefreshTests: XCTestCase {
    func testSuccessfulRefreshRestoresInMemorySession() async throws {
        let credentialStore = try makeConfiguredCredentialStore()
        let authRepository = MockAuthRepository()
        let vaultSession = MockVaultSession()

        let viewModel = AuthFlowTestSupport.makeUnlockViewModel(
            credentialStore: credentialStore,
            authRepository: authRepository,
            vaultSession: vaultSession,
            networkReachability: MockNetworkReachability(isOnline: true)
        )
        viewModel.password = "secret"

        await viewModel.unlockWithPassword()

        let restoreCallCount = await authRepository.restoreSessionCallCount
        let loginCallCount = await authRepository.loginCallCount
        let currentSession = await authRepository.currentSession
        let establishedKeys = await vaultSession.establishedKeys

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(restoreCallCount, 1)
        XCTAssertEqual(loginCallCount, 0)
        XCTAssertNotNil(currentSession)
        XCTAssertNotNil(establishedKeys)
    }

    func testFailedRefreshShowsSoftError() async throws {
        let credentialStore = try makeConfiguredCredentialStore()
        let authRepository = MockAuthRepository()
        await authRepository.setRestoreError(.invalidCredentials)
        await authRepository.setLoginError(.invalidCredentials)

        let viewModel = AuthFlowTestSupport.makeUnlockViewModel(
            credentialStore: credentialStore,
            authRepository: authRepository,
            networkReachability: MockNetworkReachability(isOnline: true)
        )
        viewModel.password = "secret"

        await viewModel.unlockWithPassword()

        XCTAssertEqual(viewModel.state, .failure(.sessionExpired))
    }

    func testRefreshRetriedWithEnteredPasswordOnSoftFailure() async throws {
        let credentialStore = try makeConfiguredCredentialStore()
        let authRepository = MockAuthRepository()
        await authRepository.setRestoreError(.invalidCredentials)

        let viewModel = AuthFlowTestSupport.makeUnlockViewModel(
            credentialStore: credentialStore,
            authRepository: authRepository,
            networkReachability: MockNetworkReachability(isOnline: true)
        )
        viewModel.password = "secret"

        await viewModel.unlockWithPassword()

        let loginCallCount = await authRepository.loginCallCount
        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(loginCallCount, 1)
    }

    func testOfflineSkipsRefresh() async throws {
        let credentialStore = try makeConfiguredCredentialStore()
        let authRepository = MockAuthRepository()
        let vaultSession = MockVaultSession()

        let viewModel = AuthFlowTestSupport.makeUnlockViewModel(
            credentialStore: credentialStore,
            authRepository: authRepository,
            vaultSession: vaultSession,
            networkReachability: MockNetworkReachability(isOnline: false)
        )
        viewModel.password = "secret"

        await viewModel.unlockWithPassword()

        let restoreCallCount = await authRepository.restoreSessionCallCount
        let loginCallCount = await authRepository.loginCallCount
        let establishedKeys = await vaultSession.establishedKeys

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(restoreCallCount, 0)
        XCTAssertEqual(loginCallCount, 0)
        XCTAssertNotNil(establishedKeys)
    }

    private func makeConfiguredCredentialStore() throws -> MockCredentialStore {
        let credentialStore = MockCredentialStore()
        try credentialStore.saveSetup(
            email: "user@example.com",
            refreshToken: "refresh-token",
            vaultHeader: Data([0x01, 0x02])
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
