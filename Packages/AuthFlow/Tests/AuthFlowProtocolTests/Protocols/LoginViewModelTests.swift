import AuthFlowProtocol
import Observation
import XCTest

final class LoginViewModelTests: XCTestCase {
    @MainActor
    func testMockLoginViewModelHasInitialIdleState() {
        let viewModel = MockLoginViewModel()
        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(viewModel.email, "")
        XCTAssertEqual(viewModel.password, "")
    }
}

@Observable
@MainActor
private final class MockLoginViewModel: LoginViewModel {
    var email = ""
    var password = ""
    private(set) var state: AuthFormState = .idle

    func login() async {}
}
