import XCTest

@testable import VaultRepositoryProtocol

final class VaultRepositoryErrorTests: XCTestCase {
    func testErrorCasesAreEquatable() {
        XCTAssertEqual(VaultRepositoryError.notAuthenticated, .notAuthenticated)
        XCTAssertEqual(VaultRepositoryError.headerNotFound, .headerNotFound)
        XCTAssertEqual(VaultRepositoryError.publicKeyNotFound, .publicKeyNotFound)
        XCTAssertEqual(VaultRepositoryError.validationError("bad"), .validationError("bad"))
        XCTAssertEqual(VaultRepositoryError.networkError, .networkError)
        XCTAssertEqual(VaultRepositoryError.serverError(statusCode: 500), .serverError(statusCode: 500))
    }
}
