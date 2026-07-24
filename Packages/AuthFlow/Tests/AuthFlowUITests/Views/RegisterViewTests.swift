import AuthFlowUI
import XCTest

@testable import AuthFlowUI

@MainActor
final class RegisterViewTests: XCTestCase {
    func testRegisterViewIsPubliclyConstructible() {
        let deps = PreviewSupport.makeDependencies()
        _ = RegisterView(viewModel: deps.makeRegisterViewModel())
    }
}