import AuthFlowDomain
import AuthFlowDomainProtocol
import AuthFlowProtocol
import XCTest

@MainActor
final class UnlockUseCaseTests: XCTestCase {
    func testUnlockRestoresOnlineSessionWhenOnline() async throws {
        let credentialStore = try makeConfiguredCredentialStore()
        let authRepository = MockAuthRepository()
        let useCase = AuthFlowTestSupport.makeUnlockUseCase(
            credentialStore: credentialStore,
            networkReachability: MockNetworkReachability(isOnline: true),
            authRepository: authRepository
        )

        try await useCase.execute(password: "secret", email: "user@example.com")

        let restoreCallCount = await authRepository.restoreSessionCallCount
        XCTAssertEqual(restoreCallCount, 1)
    }

    func testUnlockFlushesPendingSyncWhenOnline() async throws {
        let credentialStore = try makeConfiguredCredentialStore()
        let noteSync = MockNoteSyncService()
        let useCase = AuthFlowTestSupport.makeUnlockUseCase(
            credentialStore: credentialStore,
            networkReachability: MockNetworkReachability(isOnline: true),
            noteSync: noteSync
        )

        try await useCase.execute(password: "secret", email: "user@example.com")

        let flushCount = await noteSync.flushCallCount
        XCTAssertEqual(flushCount, 1)
    }

    func testUnlockSurfacesVaultUnlockFailure() async throws {
        let credentialStore = try makeConfiguredCredentialStore()
        let vaultAuthenticator = MockVaultAuthenticator()
        vaultAuthenticator.unlockVaultError = TestError.unlockFailed
        let useCase = AuthFlowTestSupport.makeUnlockUseCase(
            credentialStore: credentialStore,
            vaultAuthenticator: vaultAuthenticator
        )

        do {
            try await useCase.execute(password: "secret", email: "user@example.com")
            XCTFail("Expected vault unlock failure")
        } catch {
            XCTAssertEqual(error as? AuthFlowError, .vaultUnlockFailed)
        }
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

private enum TestError: Error {
    case unlockFailed
}
