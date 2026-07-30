import AuthFlowProtocol
import XCTest

@MainActor
final class DefaultLoginViewModelPersistenceTests: XCTestCase {
    func testSaveSetupMarksDeviceReady() async throws {
        let credentialStore = MockCredentialStore()
        let vaultRepository = MockVaultRepository()
        let viewModel = AuthFlowTestSupport.makeLoginViewModel(
            vaultRepository: vaultRepository,
            credentialStore: credentialStore
        )
        viewModel.email = "user@example.com"
        viewModel.password = "secret"

        await viewModel.login()

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertTrue(credentialStore.hasLocalSetup)
        XCTAssertEqual(credentialStore.email(), "user@example.com")
        XCTAssertEqual(credentialStore.refreshToken(), "refresh")
        let headerData = await vaultRepository.headerData
        XCTAssertEqual(credentialStore.vaultHeader(), headerData)
        XCTAssertTrue(viewModel.pendingBiometricEnrollment)
    }
}
