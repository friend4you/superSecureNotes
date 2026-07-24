import AuthFlowProtocol
import XCTest

@MainActor
final class DefaultLoginViewModelNavigationTests: XCTestCase {
    func testRegisterTappedShowsRegister() {
        let navigator = MockLoginNavigator()
        let viewModel = makeViewModel(navigator: navigator)

        viewModel.registerTapped()

        XCTAssertEqual(navigator.showRegisterCallCount, 1)
    }

    private func makeViewModel(navigator: MockLoginNavigator) -> DefaultLoginViewModel {
        DefaultLoginViewModel(
            authRepository: MockAuthRepository(),
            vaultRepository: MockVaultRepository(),
            vaultAuthenticator: MockVaultAuthenticator(),
            vaultSession: MockVaultSession(),
            navigator: navigator
        )
    }
}
