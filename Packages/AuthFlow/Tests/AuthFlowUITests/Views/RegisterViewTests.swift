import AuthFlowUI
import XCTest

@testable import AuthFlowUI

@MainActor
final class RegisterViewTests: XCTestCase {
    func testRegisterViewIsPubliclyConstructible() {
        _ = RegisterView(viewModel: PreviewSupport.makeRegisterViewModel())
    }
}
