import AuthFlowRoutes
import AuthFlowUI
import NavigationProtocol
import XCTest

@testable import AuthFlowUI

@MainActor
final class LoginViewRoutingTests: XCTestCase {
    func testLoginViewSourceHasNoNavigationLink() throws {
        let source = try Self.loginViewSource()

        XCTAssertFalse(
            source.contains("NavigationLink"),
            "LoginView must not use NavigationLink to reach RegisterView"
        )
    }

    func testLoginViewSourceDoesNotReferenceRouter() throws {
        let source = try Self.loginViewSource()

        XCTAssertFalse(source.contains("NavigationRouting"))
        XCTAssertFalse(source.contains("navigationRouter"))
        XCTAssertFalse(source.contains("AuthRoute"))
    }

    private static func loginViewSource() throws -> String {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Views
            .deletingLastPathComponent() // AuthFlowUITests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // AuthFlow package root
        let sourceURL = packageRoot
            .appendingPathComponent("Sources/AuthFlowUI/Views/LoginView.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
