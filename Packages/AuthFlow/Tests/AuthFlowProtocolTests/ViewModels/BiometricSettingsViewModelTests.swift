import AuthFlowDomain
import AuthFlowDomainProtocol
import AuthFlowProtocol
import AuthRepositoryProtocol
import XCTest

@MainActor
final class BiometricSettingsViewModelTests: XCTestCase {
    func testLogoutCallsPerformLogout() async {
        var logoutCallCount = 0
        let viewModel = makeViewModel(performLogout: {
            logoutCallCount += 1
        })

        await viewModel.logout()

        XCTAssertEqual(logoutCallCount, 1)
    }

    func testDismissCallsNavigatorDismissPresentation() {
        let navigator = MockNavigating()
        let viewModel = makeViewModel(navigator: navigator)

        viewModel.dismiss()

        XCTAssertEqual(navigator.dismissPresentationCallCount, 1)
    }

    func testEnablingRequiresPasswordConfirmationWhenCacheEmpty() async {
        let credentialStore = MockCredentialStore()
        let sessionPasswordCache = SessionPasswordCache()
        let viewModel = makeViewModel(
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
        let viewModel = makeViewModel(
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
        let viewModel = makeViewModel(
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

        let viewModel = makeViewModel(
            credentialStore: credentialStore,
            sessionPasswordCache: sessionPasswordCache
        )
        XCTAssertTrue(viewModel.isBiometricsEnabled)

        await viewModel.disableBiometrics()

        XCTAssertFalse(viewModel.isBiometricsEnabled)
        XCTAssertFalse(credentialStore.bioEnabled())
        XCTAssertThrowsError(try credentialStore.loadPasswordWithBiometrics())
    }

    func testBeginDeleteAccountActivatesPasswordFlow() {
        let viewModel = makeViewModel()

        viewModel.beginDeleteAccount()

        XCTAssertTrue(viewModel.isDeleteAccountFlowActive)
        XCTAssertEqual(viewModel.deleteAccountPassword, "")
        XCTAssertNil(viewModel.deleteAccountError)
    }

    func testDeleteAccountCallsUseCaseWithPassword() async throws {
        let authRepository = MockAuthRepository()
        var resetCallCount = 0
        let useCase = DefaultDeleteAccountUseCase(
            authRepository: authRepository,
            performFullReset: { resetCallCount += 1 }
        )
        let viewModel = makeViewModel(deleteAccountUseCase: useCase)
        viewModel.beginDeleteAccount()
        viewModel.deleteAccountPassword = "secret-password"

        await viewModel.deleteAccount()

        let deleteCallCount = await authRepository.deleteAccountCallCount
        XCTAssertEqual(deleteCallCount, 1)
        XCTAssertEqual(resetCallCount, 1)
        XCTAssertFalse(viewModel.isDeleteAccountFlowActive)
        XCTAssertNil(viewModel.deleteAccountError)
    }

    func testFailedDeleteAccountPreservesFlowAndSurfacesError() async {
        let authRepository = MockAuthRepository()
        await authRepository.setDeleteAccountError(.invalidCredentials)
        var resetCallCount = 0
        let useCase = DefaultDeleteAccountUseCase(
            authRepository: authRepository,
            performFullReset: { resetCallCount += 1 }
        )
        let viewModel = makeViewModel(deleteAccountUseCase: useCase)
        viewModel.beginDeleteAccount()
        viewModel.deleteAccountPassword = "wrong-password"

        await viewModel.deleteAccount()

        XCTAssertEqual(resetCallCount, 0)
        XCTAssertTrue(viewModel.isDeleteAccountFlowActive)
        XCTAssertEqual(viewModel.deleteAccountError, .invalidCredentials)
    }

    private func makeViewModel(
        credentialStore: MockCredentialStore? = nil,
        sessionPasswordCache: SessionPasswordCache? = nil,
        navigator: MockNavigating? = nil,
        deleteAccountUseCase: (any DeleteAccountUseCase)? = nil,
        performLogout: @escaping () async -> Void = {}
    ) -> DefaultBiometricSettingsViewModel {
        let credentialStore = credentialStore ?? MockCredentialStore()
        let sessionPasswordCache = sessionPasswordCache ?? SessionPasswordCache()
        let navigator = navigator ?? MockNavigating()
        return DefaultBiometricSettingsViewModel(
            credentialStore: credentialStore,
            sessionPasswordCache: sessionPasswordCache,
            navigator: navigator,
            deleteAccountUseCase: deleteAccountUseCase ?? DefaultDeleteAccountUseCase(
                authRepository: MockAuthRepository(),
                performFullReset: {}
            ),
            performLogout: performLogout
        )
    }
}
