import XCTest

@testable import AuthRepositoryProtocol

final class AuthRepositoryErrorTests: XCTestCase {
    func testErrorCasesAreEquatable() {
        XCTAssertEqual(AuthRepositoryError.invalidCredentials, .invalidCredentials)
        XCTAssertEqual(AuthRepositoryError.emailAlreadyExists, .emailAlreadyExists)
        XCTAssertEqual(AuthRepositoryError.validationError("bad"), .validationError("bad"))
        XCTAssertEqual(AuthRepositoryError.notAuthenticated, .notAuthenticated)
        XCTAssertEqual(AuthRepositoryError.networkError, .networkError)
        XCTAssertEqual(
            AuthRepositoryError.serverError(statusCode: 500, message: nil),
            .serverError(statusCode: 500, message: nil)
        )
    }

    func testLocalizedDescriptionUsesBackendMessage() {
        XCTAssertEqual(
            AuthRepositoryError.validationError("Password too short.").errorDescription,
            "Password too short."
        )
        XCTAssertEqual(
            AuthRepositoryError.serverError(statusCode: 500, message: "Boom.").errorDescription,
            "Boom."
        )
    }
}
