import AuthFlowProtocol
import AuthFlowRoutes
import XCTest

@MainActor
final class DefaultRegisterViewModelEnrollmentTests: XCTestCase {
    func testRegisterPresentsEnrollmentOnWasFirstSetup() async {
        let navigator = MockNavigating()
        let pendingStore = MockPendingBiometricEnrollmentStore()
        let viewModel = AuthFlowTestSupport.makeRegisterViewModel(
            navigator: navigator,
            pendingBiometricEnrollmentStore: pendingStore
        )
        viewModel.email = "user@example.com"
        viewModel.password = "secret"

        await viewModel.register()

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertTrue(pendingStore.isPending)
        XCTAssertEqual(navigator.presentedRoutes.count, 1)
        XCTAssertEqual(navigator.presentedRoutes.first?.route, AnyHashable(AuthRoute.biometricEnrollment))
    }
}
