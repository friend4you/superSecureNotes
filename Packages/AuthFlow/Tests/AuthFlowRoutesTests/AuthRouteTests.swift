import NavigationProtocol
import XCTest

@testable import AuthFlowRoutes

final class AuthRouteTests: XCTestCase {
    func testAuthRouteConformsToRoute() {
        let route: any Route = AuthRoute.login
        XCTAssertTrue(route is AuthRoute)
    }

    func testAuthRouteIncludesLoginAndRegister() {
        XCTAssertEqual(AuthRoute.login, .login)
        XCTAssertEqual(AuthRoute.register, .register)
        XCTAssertNotEqual(AuthRoute.login, .register)
    }

    func testAuthRouteIncludesBiometricEnrollment() {
        XCTAssertEqual(AuthRoute.biometricEnrollment, .biometricEnrollment)
    }

    func testAuthRouteIsSendable() {
        let route: any Route & Sendable = AuthRoute.login
        XCTAssertTrue(route is AuthRoute)
    }
}
