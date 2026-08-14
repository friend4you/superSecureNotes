import AuthFlowUI
import XCTest

@testable import AuthFlowUI

@MainActor
final class LoginViewTests: XCTestCase {
    func testLoginViewIsPubliclyConstructible() {
        _ = LoginView(viewModel: PreviewSupport.makeLoginViewModel())
    }

    func testLoginViewUsesSectionBuilders() throws {
        let source = try Self.viewSource(named: "LoginView.swift")
        XCTAssertTrue(source.contains("credentialsSection"))
        XCTAssertTrue(source.contains("errorSection"))
        XCTAssertTrue(source.contains("actionsSection"))
        XCTAssertFalse(source.contains(".sheet"))
    }

    private static func viewSource(named fileName: String) throws -> String {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = packageRoot
            .appendingPathComponent("Sources/AuthFlowUI/Views")
            .appendingPathComponent(fileName)
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
