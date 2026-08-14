import AuthFlowProtocol
import AuthFlowRoutes
import XCTest

@MainActor
final class DefaultRegisterViewModelEnrollmentTests: XCTestCase {
    func testRegisterPresentsEnrollmentOnWasFirstSetup() async {
        let navigator = MockNavigating()
        let viewModel = AuthFlowTestSupport.makeRegisterViewModel(navigator: navigator)
        viewModel.email = "user@example.com"
        viewModel.password = "secret"

        await viewModel.register()

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(navigator.presentedRoutes.count, 1)
        XCTAssertEqual(navigator.presentedRoutes.first?.route, AnyHashable(AuthRoute.biometricEnrollment))
    }
}
