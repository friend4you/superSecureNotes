import AuthFlowProtocol
import XCTest

@MainActor
final class DefaultRegisterViewModelSuccessTests: XCTestCase {
    func testRegisterSucceedsAndUploadsVaultHeader() async {
        let authRepository = MockAuthRepository()
        let vaultRepository = MockVaultRepository()
        let authenticator = MockVaultAuthenticator()
        let vaultSession = MockVaultSession()
        let viewModel = AuthFlowTestSupport.makeRegisterViewModel(
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

    func testRegisterSchedulesVaultHeaderUploadWithoutBlocking() async {
        let vaultHeaderUploader = MockVaultHeaderUploadScheduler()
        let viewModel = AuthFlowTestSupport.makeRegisterViewModel(
            vaultHeaderUploader: vaultHeaderUploader
        )
        viewModel.email = "user@example.com"
        viewModel.password = "secret"

        await viewModel.register()

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(vaultHeaderUploader.scheduledHeaders.count, 1)
        XCTAssertEqual(vaultHeaderUploader.scheduledHeaders[0], Data([0x0A]))
    }
}
