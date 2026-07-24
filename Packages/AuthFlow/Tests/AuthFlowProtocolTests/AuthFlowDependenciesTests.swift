import AuthFlowProtocol
import XCTest

@MainActor
final class AuthFlowDependenciesTests: XCTestCase {
    func testAuthFlowDependenciesConformsToAuthFlowDependencyProviding() {
        let dependencies: any AuthFlowDependencyProviding = AuthFlowDependencies(
            authRepository: MockAuthRepository(),
            vaultRepository: MockVaultRepository(),
            vaultAuthenticator: MockVaultAuthenticator(),
            vaultSession: MockVaultSession()
        )

        XCTAssertTrue(dependencies is AuthFlowDependencies)
    }

    func testMakeLoginViewModelUsesInjectedNavigator() {
        let navigator = MockLoginNavigator()
        let dependencies = AuthFlowDependencies(
            authRepository: MockAuthRepository(),
            vaultRepository: MockVaultRepository(),
            vaultAuthenticator: MockVaultAuthenticator(),
            vaultSession: MockVaultSession()
        )

        _ = dependencies.makeLoginViewModel(navigator: navigator)

        XCTAssertEqual(navigator.showRegisterCallCount, 0)
    }
}
