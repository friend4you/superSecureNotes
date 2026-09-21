import AuthFlowProtocol
import AuthFlowRoutes
import XCTest

@MainActor
final class AuthFlowDependenciesTests: XCTestCase {
    func testAuthFlowDependenciesConformsToAuthFlowDependencyProviding() {
        let dependencies: any AuthFlowDependencyProviding = makeDependencies()

        XCTAssertTrue(dependencies is AuthFlowDependencies)
    }

    func testMakeLoginViewModelUsesNavigatorFromDependencies() {
        let navigator = MockNavigating()
        let dependencies = makeDependencies(navigator: navigator)

        let viewModel = dependencies.makeLoginViewModel()
        viewModel.registerTapped()

        XCTAssertEqual(navigator.pushedRoutes.count, 1)
        XCTAssertEqual(navigator.pushedRoutes.first?.base as? AuthRoute, .register)
    }

    func testMakeBiometricSettingsViewModelWiresDeleteAccountUseCase() async {
        var resetCallCount = 0
        let authRepository = MockAuthRepository()
        let dependencies = AuthFlowDependencies(
            authRepository: authRepository,
            vaultRepository: MockVaultRepository(),
            vaultAuthenticator: MockVaultAuthenticator(),
            vaultSession: MockVaultSession(),
            notesIndexStore: MockNotesIndexStore(),
            navigator: MockNavigating(),
            credentialStore: MockCredentialStore(),
            biometricAuthenticator: MockBiometricAuthenticator(),
            networkReachability: MockNetworkReachability(isOnline: true),
            sessionPasswordCache: SessionPasswordCache(),
            performLogout: { resetCallCount += 1 }
        )

        let viewModel = dependencies.makeBiometricSettingsViewModel()
        viewModel.beginDeleteAccount()
        viewModel.deleteAccountPassword = "secret-password"
        await viewModel.deleteAccount()

        let deleteCallCount = await authRepository.deleteAccountCallCount
        XCTAssertEqual(deleteCallCount, 1)
        XCTAssertEqual(resetCallCount, 1)
    }

    private func makeDependencies(navigator: MockNavigating? = nil) -> AuthFlowDependencies {
        AuthFlowDependencies(
            authRepository: MockAuthRepository(),
            vaultRepository: MockVaultRepository(),
            vaultAuthenticator: MockVaultAuthenticator(),
            vaultSession: MockVaultSession(),
            notesIndexStore: MockNotesIndexStore(),
            navigator: navigator ?? MockNavigating(),
            credentialStore: MockCredentialStore(),
            biometricAuthenticator: MockBiometricAuthenticator(),
            networkReachability: MockNetworkReachability(isOnline: true),
            sessionPasswordCache: SessionPasswordCache()
        )
    }
}
