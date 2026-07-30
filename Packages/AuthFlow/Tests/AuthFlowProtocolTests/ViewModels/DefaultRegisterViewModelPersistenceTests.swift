import AuthFlowProtocol
import XCTest

@MainActor
final class DefaultRegisterViewModelPersistenceTests: XCTestCase {
    func testSaveSetupMarksDeviceReady() async throws {
        let credentialStore = MockCredentialStore()
        let authenticator = MockVaultAuthenticator()
        let viewModel = AuthFlowTestSupport.makeRegisterViewModel(
            vaultAuthenticator: authenticator,
            credentialStore: credentialStore
        )
        viewModel.email = "user@example.com"
        viewModel.password = "secret"

        await viewModel.register()

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertTrue(credentialStore.hasLocalSetup)
        XCTAssertEqual(credentialStore.email(), "user@example.com")
        XCTAssertEqual(credentialStore.refreshToken(), "refresh")
        XCTAssertEqual(credentialStore.vaultHeader(), authenticator.creationOutcome.headerData)
        XCTAssertTrue(viewModel.pendingBiometricEnrollment)
    }
}
