import AuthFlowProtocol
import Observation
import XCTest

final class UnlockViewModelTests: XCTestCase {
    @MainActor
    func testUnlockViewModelProtocolCompiles() {
        let viewModel: any UnlockViewModel = MockUnlockViewModel()
        XCTAssertEqual(viewModel.state, .awaitingPresence)
    }

    @MainActor
    func testMockSatisfiesContractWithLockedInitialState() {
        let viewModel = MockUnlockViewModel()

        XCTAssertEqual(viewModel.email, "user@example.com")
        XCTAssertEqual(viewModel.password, "")
        XCTAssertEqual(viewModel.state, .awaitingPresence)
    }

    func testUnlockFormStateIsEquatableAndSendable() {
        let lhs: UnlockFormState = .awaitingPresence
        let rhs: UnlockFormState = .awaitingPresence
        XCTAssertEqual(lhs, rhs)

        let sendable: any Sendable = UnlockFormState.passwordEntry
        XCTAssertNotNil(sendable)
    }
}

@Observable
@MainActor
private final class MockUnlockViewModel: UnlockViewModel {
    let email = "user@example.com"
    var password = ""
    private(set) var state: UnlockFormState = .awaitingPresence

    func onAppear() async {}

    func unlockWithPassword() async {}

    func retryBiometrics() async {}

    func logout() async {}
}
