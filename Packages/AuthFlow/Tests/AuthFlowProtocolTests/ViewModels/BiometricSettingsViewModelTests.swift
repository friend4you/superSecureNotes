import AuthFlowProtocol
import XCTest

@MainActor
final class BiometricSettingsViewModelTests: XCTestCase {
    func testLogoutCallsPerformLogout() async {
        var logoutCallCount = 0
        let viewModel = DefaultBiometricSettingsViewModel(
            credentialStore: MockCredentialStore(),
            sessionPasswordCache: SessionPasswordCache(),
            navigator: MockNavigating(),
            performLogout: {
                logoutCallCount += 1
            }
        )

        await viewModel.logout()

        XCTAssertEqual(logoutCallCount, 1)
    }

    func testDismissCallsNavigatorDismissPresentation() {
        let navigator = MockNavigating()
        let viewModel = DefaultBiometricSettingsViewModel(
            credentialStore: MockCredentialStore(),
            sessionPasswordCache: SessionPasswordCache(),
            navigator: navigator,
            performLogout: {}
        )

        viewModel.dismiss()

        XCTAssertEqual(navigator.dismissPresentationCallCount, 1)
    }

    func testEnablingRequiresPasswordConfirmationWhenCacheEmpty() async {
        let credentialStore = MockCredentialStore()
        let sessionPasswordCache = SessionPasswordCache()
        let viewModel = DefaultBiometricSettingsViewModel(
            credentialStore: credentialStore,
            sessionPasswordCache: sessionPasswordCache,
            navigator: MockNavigating(),
            performLogout: {}
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
            sessionPasswordCache: sessionPasswordCache,
            navigator: MockNavigating(),
            performLogout: {}
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
            sessionPasswordCache: sessionPasswordCache,
            navigator: MockNavigating(),
            performLogout: {}
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
            sessionPasswordCache: sessionPasswordCache,
            navigator: MockNavigating(),
            performLogout: {}
        )
        XCTAssertTrue(viewModel.isBiometricsEnabled)

        await viewModel.disableBiometrics()

        XCTAssertFalse(viewModel.isBiometricsEnabled)
        XCTAssertFalse(credentialStore.bioEnabled())
        XCTAssertThrowsError(try credentialStore.loadPasswordWithBiometrics())
    }
}
