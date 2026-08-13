import XCTest

@testable import VaultRepositoryProtocol

final class VaultRepositoryErrorTests: XCTestCase {
    func testErrorCasesAreEquatable() {
        XCTAssertEqual(VaultRepositoryError.notAuthenticated, .notAuthenticated)
        XCTAssertEqual(VaultRepositoryError.headerNotFound, .headerNotFound)
        XCTAssertEqual(VaultRepositoryError.publicKeyNotFound, .publicKeyNotFound)
        XCTAssertEqual(VaultRepositoryError.userNotFound("missing"), .userNotFound("missing"))
        XCTAssertEqual(VaultRepositoryError.validationError("bad"), .validationError("bad"))
        XCTAssertEqual(VaultRepositoryError.networkError, .networkError)
        XCTAssertEqual(
            VaultRepositoryError.serverError(statusCode: 500, message: nil),
            .serverError(statusCode: 500, message: nil)
        )
    }

    func testLocalizedDescriptionUsesBackendMessage() {
        XCTAssertEqual(
            VaultRepositoryError.userNotFound("Recipient user not found.").errorDescription,
            "Recipient user not found."
        )
        XCTAssertEqual(
            VaultRepositoryError.serverError(statusCode: 500, message: "Boom.").errorDescription,
            "Boom."
        )
    }
}
