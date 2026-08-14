import AuthFlowProtocol
import AuthFlowRoutes
import XCTest

@MainActor
final class DefaultLoginViewModelEnrollmentTests: XCTestCase {
    func testLoginPresentsEnrollmentOnWasFirstSetup() async {
        let navigator = MockNavigating()
        let credentialStore = MockCredentialStore()
        let viewModel = AuthFlowTestSupport.makeLoginViewModel(
            navigator: navigator,
            credentialStore: credentialStore
        )
        viewModel.email = "user@example.com"
        viewModel.password = "secret"

        await viewModel.login()

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(navigator.presentedRoutes.count, 1)
        XCTAssertEqual(navigator.presentedRoutes.first?.route, AnyHashable(AuthRoute.biometricEnrollment))
    }

    func testRepeatLoginDoesNotPresentEnrollment() async throws {
        let navigator = MockNavigating()
        let credentialStore = MockCredentialStore()
        try credentialStore.saveSetup(
            email: "user@example.com",
            refreshToken: "refresh",
            vaultHeader: Data([0x01])
        )
        let viewModel = AuthFlowTestSupport.makeLoginViewModel(
            navigator: navigator,
            credentialStore: credentialStore
        )
        viewModel.email = "user@example.com"
        viewModel.password = "secret"

        await viewModel.login()

        XCTAssertTrue(navigator.presentedRoutes.isEmpty)
    }
}
