import AuthFlowProtocol
import XCTest

@MainActor
final class DefaultLoginViewModelSuccessTests: XCTestCase {
    func testLoginSucceedsAndEstablishesVaultSession() async {
        let authRepository = MockAuthRepository()
        let vaultRepository = MockVaultRepository()
        let authenticator = MockVaultAuthenticator()
        let vaultSession = MockVaultSession()
        let viewModel = DefaultLoginViewModel(
            authRepository: authRepository,
            vaultRepository: vaultRepository,
            vaultAuthenticator: authenticator,
            vaultSession: vaultSession
        )
        viewModel.email = "user@example.com"
        viewModel.password = "secret"

        await viewModel.login()

        XCTAssertEqual(viewModel.state, .idle)
        let loginCallCount = await authRepository.loginCallCount
        let readHeaderCallCount = await vaultRepository.readHeaderCallCount
        XCTAssertEqual(loginCallCount, 1)
        XCTAssertEqual(readHeaderCallCount, 1)
        XCTAssertEqual(authenticator.unlockVaultCallCount, 1)
        let establishedKeys = await vaultSession.establishedKeys
        XCTAssertNotNil(establishedKeys)
    }
}
