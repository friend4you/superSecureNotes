import AuthFlowDomain
import AuthRepositoryProtocol
import XCTest

@MainActor
final class RestoreOnlineSessionUseCaseTests: XCTestCase {
    func testRestoreSucceedsWithRefreshToken() async throws {
        let credentialStore = try makeConfiguredCredentialStore()
        let authRepository = MockAuthRepository()
        let useCase = AuthFlowTestSupport.makeRestoreOnlineSessionUseCase(
            credentialStore: credentialStore,
            authRepository: authRepository
        )

        try await useCase.execute(email: "user@example.com", password: "secret")

        let restoreCallCount = await authRepository.restoreSessionCallCount
        let loginCallCount = await authRepository.loginCallCount
        XCTAssertEqual(restoreCallCount, 1)
        XCTAssertEqual(loginCallCount, 0)
    }

    func testRestoreFailureRetriesLogin() async throws {
        let credentialStore = try makeConfiguredCredentialStore()
        let authRepository = MockAuthRepository()
        await authRepository.setRestoreError(.invalidCredentials)
        let useCase = AuthFlowTestSupport.makeRestoreOnlineSessionUseCase(
            credentialStore: credentialStore,
            authRepository: authRepository
        )

        try await useCase.execute(email: "user@example.com", password: "secret")

        let loginCallCount = await authRepository.loginCallCount
        XCTAssertEqual(loginCallCount, 1)
    }

    func testNetworkErrorDuringRestoreIsIgnored() async throws {
        let credentialStore = try makeConfiguredCredentialStore()
        let authRepository = MockAuthRepository()
        await authRepository.setRestoreError(.networkError)
        let useCase = AuthFlowTestSupport.makeRestoreOnlineSessionUseCase(
            credentialStore: credentialStore,
            authRepository: authRepository
        )

        try await useCase.execute(email: "user@example.com", password: "secret")

        let loginCallCount = await authRepository.loginCallCount
        XCTAssertEqual(loginCallCount, 0)
    }

    private func makeConfiguredCredentialStore() throws -> MockCredentialStore {
        let credentialStore = MockCredentialStore()
        try credentialStore.saveSetup(
            email: "user@example.com",
            refreshToken: "refresh-token",
            vaultHeader: Data([0x01])
        )
        return credentialStore
    }
}

private extension MockAuthRepository {
    func setRestoreError(_ error: AuthRepositoryError) {
        restoreError = error
    }
}
