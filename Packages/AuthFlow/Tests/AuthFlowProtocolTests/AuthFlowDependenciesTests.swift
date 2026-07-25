import AuthFlowProtocol
import AuthFlowRoutes
import XCTest

@MainActor
final class AuthFlowDependenciesTests: XCTestCase {
    func testAuthFlowDependenciesConformsToAuthFlowDependencyProviding() {
        let dependencies: any AuthFlowDependencyProviding = AuthFlowDependencies(
            authRepository: MockAuthRepository(),
            vaultRepository: MockVaultRepository(),
            vaultAuthenticator: MockVaultAuthenticator(),
            vaultSession: MockVaultSession(),
            navigator: MockNavigating()
        )

        XCTAssertTrue(dependencies is AuthFlowDependencies)
    }

    func testMakeLoginViewModelUsesNavigatorFromDependencies() {
        let navigator = MockNavigating()
        let dependencies = AuthFlowDependencies(
            authRepository: MockAuthRepository(),
            vaultRepository: MockVaultRepository(),
            vaultAuthenticator: MockVaultAuthenticator(),
            vaultSession: MockVaultSession(),
            navigator: navigator
        )

        let viewModel = dependencies.makeLoginViewModel()
        viewModel.registerTapped()

        XCTAssertEqual(navigator.pushedRoutes.count, 1)
        XCTAssertEqual(navigator.pushedRoutes.first?.base as? AuthRoute, .register)
    }
}
