import XCTest

@testable import AuthRepositoryProtocol

final class ModelsTests: XCTestCase {
    func testUserHoldsIdentityFields() {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let user = User(id: "user-id", email: "user@example.com", createdAt: createdAt)

        XCTAssertEqual(user.id, "user-id")
        XCTAssertEqual(user.email, "user@example.com")
        XCTAssertEqual(user.createdAt, createdAt)
        XCTAssertEqual(user, User(id: "user-id", email: "user@example.com", createdAt: createdAt))
    }

    func testAuthSessionHoldsTokenFields() {
        let expiresAt = Date(timeIntervalSince1970: 1_800_000_000)
        let session = AuthSession(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            expiresAt: expiresAt
        )

        XCTAssertEqual(session.accessToken, "access-token")
        XCTAssertEqual(session.refreshToken, "refresh-token")
        XCTAssertEqual(session.expiresAt, expiresAt)
        XCTAssertEqual(
            session,
            AuthSession(accessToken: "access-token", refreshToken: "refresh-token", expiresAt: expiresAt)
        )
    }
}
