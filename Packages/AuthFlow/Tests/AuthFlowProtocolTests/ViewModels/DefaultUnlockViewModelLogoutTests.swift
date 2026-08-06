import AuthFlowProtocol
import XCTest

@MainActor
final class DefaultUnlockViewModelLogoutTests: XCTestCase {
    func testLogoutInvokesPerformLogoutClosure() async {
        var logoutCallCount = 0
        let viewModel = AuthFlowTestSupport.makeUnlockViewModel(
            performLogout: {
                logoutCallCount += 1
            }
        )

        await viewModel.logout()

        XCTAssertEqual(logoutCallCount, 1)
    }
}
