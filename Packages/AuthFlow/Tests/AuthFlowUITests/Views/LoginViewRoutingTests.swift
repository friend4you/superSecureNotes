import AuthFlowRoutes
import AuthFlowUI
import NavigationProtocol
import XCTest

@testable import AuthFlowUI

@MainActor
private final class MockNavigationRouter: NavigationRouting {
    private(set) var pushedRoutes: [AnyHashable] = []

    func setRoot<R: Route>(_ route: R) {}

    func push<R: Route>(_ route: R) {
        pushedRoutes.append(AnyHashable(route))
    }

    func present<R: Route>(_ route: R, style: RoutePresentation) {}

    func pop() {}

    func popToRoot() {}
}

@MainActor
final class AuthLoginNavigatorTests: XCTestCase {
    func testShowRegisterPushesAuthRouteRegister() {
        let router = MockNavigationRouter()
        let navigator = AuthLoginNavigator(router: router)

        navigator.showRegister()

        XCTAssertEqual(router.pushedRoutes.count, 1)
        XCTAssertEqual(router.pushedRoutes.first?.base as? AuthRoute, .register)
    }
}

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
