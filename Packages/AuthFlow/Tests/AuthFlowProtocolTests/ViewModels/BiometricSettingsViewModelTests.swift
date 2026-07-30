import AuthFlowProtocol
import XCTest

@MainActor
final class BiometricSettingsViewModelTests: XCTestCase {
    func testEnablingRequiresPasswordConfirmation() async {
        let credentialStore = MockCredentialStore()
        let viewModel = DefaultBiometricSettingsViewModel(credentialStore: credentialStore)

        await viewModel.enableBiometrics()

        XCTAssertTrue(viewModel.requiresPasswordConfirmation)
        XCTAssertFalse(viewModel.isBiometricsEnabled)
        XCTAssertFalse(credentialStore.bioEnabled())
    }

    func testEnableBiometricsWithPasswordConfirmation() async throws {
        let credentialStore = MockCredentialStore()
        let viewModel = DefaultBiometricSettingsViewModel(credentialStore: credentialStore)
        viewModel.password = "secret"

        await viewModel.enableBiometrics()

        XCTAssertTrue(viewModel.isBiometricsEnabled)
        XCTAssertFalse(viewModel.requiresPasswordConfirmation)
        XCTAssertEqual(viewModel.password, "")
        XCTAssertTrue(credentialStore.bioEnabled())
        XCTAssertEqual(try credentialStore.loadPasswordWithBiometrics(), "secret")
    }

    func testDisableBioFromSettings() async throws {
        let credentialStore = MockCredentialStore()
        try credentialStore.setBioEnabled(true)
        try credentialStore.savePassword("secret")

        let viewModel = DefaultBiometricSettingsViewModel(credentialStore: credentialStore)
        XCTAssertTrue(viewModel.isBiometricsEnabled)

        await viewModel.disableBiometrics()

        XCTAssertFalse(viewModel.isBiometricsEnabled)
        XCTAssertFalse(credentialStore.bioEnabled())
        XCTAssertThrowsError(try credentialStore.loadPasswordWithBiometrics())
    }
}
