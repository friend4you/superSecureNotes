import AuthFlowProtocol
import AuthFlowRoutes
import XCTest

@MainActor
final class DefaultLoginViewModelNavigationTests: XCTestCase {
    func testRegisterTappedPushesAuthRouteRegister() {
        let navigator = MockNavigating()
        let viewModel = makeViewModel(navigator: navigator)

        viewModel.registerTapped()

        XCTAssertEqual(navigator.pushedRoutes.count, 1)
        XCTAssertEqual(navigator.pushedRoutes.first?.base as? AuthRoute, .register)
    }

    private func makeViewModel(navigator: MockNavigating) -> DefaultLoginViewModel {
        AuthFlowTestSupport.makeLoginViewModel(navigator: navigator)
    }
}
