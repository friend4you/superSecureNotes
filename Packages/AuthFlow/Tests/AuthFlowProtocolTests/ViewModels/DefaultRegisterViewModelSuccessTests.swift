import AuthFlowProtocol
import XCTest

@MainActor
final class DefaultRegisterViewModelSuccessTests: XCTestCase {
    func testRegisterSucceedsAndUploadsVaultHeader() async {
        let authRepository = MockAuthRepository()
        let vaultRepository = MockVaultRepository()
        let authenticator = MockVaultAuthenticator()
        let vaultSession = MockVaultSession()
        let viewModel = DefaultRegisterViewModel(
            authRepository: authRepository,
            vaultRepository: vaultRepository,
            vaultAuthenticator: authenticator,
            vaultSession: vaultSession
        )
        viewModel.email = "user@example.com"
        viewModel.password = "secret"

        await viewModel.register()

        XCTAssertEqual(viewModel.state, .idle)
        let registerCallCount = await authRepository.registerCallCount
        let writeHeaderCallCount = await vaultRepository.writeHeaderCallCount
        XCTAssertEqual(registerCallCount, 1)
        XCTAssertEqual(authenticator.createVaultCallCount, 1)
        XCTAssertEqual(writeHeaderCallCount, 1)
        XCTAssertEqual(authenticator.unlockVaultCallCount, 1)
        let establishedKeys = await vaultSession.establishedKeys
        XCTAssertNotNil(establishedKeys)
    }
}
