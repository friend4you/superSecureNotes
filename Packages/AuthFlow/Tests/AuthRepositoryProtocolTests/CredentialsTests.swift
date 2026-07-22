import XCTest

@testable import AuthRepositoryProtocol

final class CredentialsTests: XCTestCase {
    func testLoginCredentialsHoldEmailAndPassword() {
        let credentials = LoginCredentials(email: "user@example.com", password: "secret")

        XCTAssertEqual(credentials.email, "user@example.com")
        XCTAssertEqual(credentials.password, "secret")
        XCTAssertEqual(credentials, LoginCredentials(email: "user@example.com", password: "secret"))
    }

    func testRegisterCredentialsHoldEmailAndPassword() {
        let credentials = RegisterCredentials(email: "user@example.com", password: "secret")

        XCTAssertEqual(credentials.email, "user@example.com")
        XCTAssertEqual(credentials.password, "secret")
        XCTAssertEqual(credentials, RegisterCredentials(email: "user@example.com", password: "secret"))
    }
}
