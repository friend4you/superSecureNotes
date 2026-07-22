import XCTest

@testable import AuthRepositoryProtocol

final class AuthRepositoryErrorTests: XCTestCase {
    func testErrorCasesAreEquatable() {
        XCTAssertEqual(AuthRepositoryError.invalidCredentials, .invalidCredentials)
        XCTAssertEqual(AuthRepositoryError.emailAlreadyExists, .emailAlreadyExists)
        XCTAssertEqual(AuthRepositoryError.validationError("bad"), .validationError("bad"))
        XCTAssertEqual(AuthRepositoryError.notAuthenticated, .notAuthenticated)
        XCTAssertEqual(AuthRepositoryError.networkError, .networkError)
        XCTAssertEqual(AuthRepositoryError.serverError(statusCode: 500), .serverError(statusCode: 500))
    }
}
