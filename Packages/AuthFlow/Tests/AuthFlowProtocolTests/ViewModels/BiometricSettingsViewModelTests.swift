import AuthFlowProtocol
import XCTest

@MainActor
final class BiometricSettingsViewModelTests: XCTestCase {
    func testEnablingRequiresPasswordConfirmationWhenCacheEmpty() async {
        let credentialStore = MockCredentialStore()
        let sessionPasswordCache = SessionPasswordCache()
        let viewModel = DefaultBiometricSettingsViewModel(
            credentialStore: credentialStore,
            sessionPasswordCache: sessionPasswordCache
        )

        await viewModel.enableBiometrics()

        XCTAssertTrue(viewModel.requiresPasswordConfirmation)
        XCTAssertFalse(viewModel.isBiometricsEnabled)
        XCTAssertFalse(credentialStore.bioEnabled())
    }

    func testEnableBiometricsUsingSessionCache() async throws {
        let credentialStore = MockCredentialStore()
        let sessionPasswordCache = SessionPasswordCache()
        sessionPasswordCache.store("secret")
        let viewModel = DefaultBiometricSettingsViewModel(
            credentialStore: credentialStore,
            sessionPasswordCache: sessionPasswordCache
        )

        await viewModel.enableBiometrics()

        XCTAssertTrue(viewModel.isBiometricsEnabled)
        XCTAssertFalse(viewModel.requiresPasswordConfirmation)
        XCTAssertTrue(credentialStore.bioEnabled())
        XCTAssertEqual(try credentialStore.loadPasswordWithBiometrics(), "secret")
    }

    func testEnableBiometricsWithPasswordFallback() async throws {
        let credentialStore = MockCredentialStore()
        let sessionPasswordCache = SessionPasswordCache()
        let viewModel = DefaultBiometricSettingsViewModel(
            credentialStore: credentialStore,
            sessionPasswordCache: sessionPasswordCache
        )
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
        let sessionPasswordCache = SessionPasswordCache()
        try credentialStore.setBioEnabled(true)
        try credentialStore.savePassword("secret")

        let viewModel = DefaultBiometricSettingsViewModel(
            credentialStore: credentialStore,
            sessionPasswordCache: sessionPasswordCache
        )
        XCTAssertTrue(viewModel.isBiometricsEnabled)

        await viewModel.disableBiometrics()

        XCTAssertFalse(viewModel.isBiometricsEnabled)
        XCTAssertFalse(credentialStore.bioEnabled())
        XCTAssertThrowsError(try credentialStore.loadPasswordWithBiometrics())
    }
}
