import AuthFlowProtocol
import Observation
import XCTest

final class RegisterViewModelTests: XCTestCase {
    @MainActor
    func testMockRegisterViewModelHasInitialIdleState() {
        let viewModel = MockRegisterViewModel()
        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(viewModel.email, "")
        XCTAssertEqual(viewModel.password, "")
    }
}

@Observable
@MainActor
private final class MockRegisterViewModel: RegisterViewModel {
    var email = ""
    var password = ""
    private(set) var state: AuthFormState = .idle

    func register() async {}
}
