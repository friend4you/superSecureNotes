import AuthFlowUI
import XCTest

@testable import AuthFlowUI

@MainActor
final class LoginViewTests: XCTestCase {
    func testLoginViewIsPubliclyConstructible() {
        _ = LoginView(
            viewModel: PreviewSupport.makeLoginViewModel(),
            makeRegisterViewModel: PreviewSupport.makeRegisterViewModel
        )
    }
}
