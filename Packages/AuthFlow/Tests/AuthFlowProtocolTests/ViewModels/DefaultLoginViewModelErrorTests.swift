import AuthRepositoryProtocol
import AuthFlowProtocol
import VaultRepositoryProtocol
import VaultRepositoryProtocol
import XCTest

@MainActor
final class DefaultLoginViewModelErrorTests: XCTestCase {
    func testLoginMapsInvalidCredentials() async {
        let authRepository = MockAuthRepository()
        await authRepository.setLoginError(.invalidCredentials)
        let viewModel = makeViewModel(authRepository: authRepository)
        viewModel.email = "user@example.com"
        viewModel.password = "secret"

        await viewModel.login()

        XCTAssertEqual(viewModel.state, .failure(.invalidCredentials))
    }

    func testLoginMapsVaultNotFound() async {
        let vaultRepository = MockVaultRepository()
        await vaultRepository.setReadHeaderError(.headerNotFound)
        let viewModel = makeViewModel(vaultRepository: vaultRepository)
        viewModel.email = "user@example.com"
        viewModel.password = "secret"

        await viewModel.login()

        XCTAssertEqual(viewModel.state, .failure(.vaultNotFound))
    }

    func testLoginMapsVaultUnlockFailure() async {
        let authenticator = MockVaultAuthenticator()
        authenticator.unlockVaultError = TestError.unlockFailed
        let viewModel = makeViewModel(authenticator: authenticator)
        viewModel.email = "user@example.com"
        viewModel.password = "secret"

        await viewModel.login()

        XCTAssertEqual(viewModel.state, .failure(.vaultUnlockFailed))
    }

    func testLoginMapsVaultNotFoundFromRemotePull() async {
        let noteSync = MockNoteSyncService()
        await noteSync.setLocalVaultHeaderExists(false)
        await noteSync.setPullVaultHeaderError(VaultRepositoryError.headerNotFound)
        let viewModel = makeViewModel(noteSync: noteSync)
        viewModel.email = "user@example.com"
        viewModel.password = "secret"

        await viewModel.login()

        XCTAssertEqual(viewModel.state, .failure(.vaultNotFound))
    }

    func testLoginMapsNetworkError() async {
        let authRepository = MockAuthRepository()
        await authRepository.setLoginError(.networkError)
        let viewModel = makeViewModel(authRepository: authRepository)
        viewModel.email = "user@example.com"
        viewModel.password = "secret"

        await viewModel.login()

        XCTAssertEqual(viewModel.state, .failure(.networkError))
    }

    private func makeViewModel(
        authRepository: MockAuthRepository = MockAuthRepository(),
        vaultRepository: MockVaultRepository = MockVaultRepository(),
        authenticator: MockVaultAuthenticator = MockVaultAuthenticator(),
        noteSync: MockNoteSyncService = MockNoteSyncService()
    ) -> DefaultLoginViewModel {
        AuthFlowTestSupport.makeLoginViewModel(
            authRepository: authRepository,
            vaultRepository: vaultRepository,
            vaultAuthenticator: authenticator,
            noteSync: noteSync
        )
    }
}

private extension MockNoteSyncService {
    func setLocalVaultHeaderExists(_ exists: Bool) {
        localVaultHeaderExists = exists
    }

    func setPullVaultHeaderError(_ error: VaultRepositoryError) {
        pullVaultHeaderError = error
    }
}

private enum TestError: Error {
    case unlockFailed
}

private extension MockAuthRepository {
    func setLoginError(_ error: AuthRepositoryError) {
        loginError = error
    }
}

private extension MockVaultRepository {
    func setReadHeaderError(_ error: VaultRepositoryError) {
        readHeaderError = error
    }
}
