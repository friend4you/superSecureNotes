import AuthFlowProtocol
import XCTest

final class AuthFormStateTests: XCTestCase {
    func testAuthFormStatesAreEquatable() {
        XCTAssertEqual(AuthFormState.idle, .idle)
        XCTAssertEqual(AuthFormState.loading, .loading)
        XCTAssertEqual(AuthFormState.failure(.invalidCredentials), .failure(.invalidCredentials))
    }

    func testAuthFlowErrorsAreEquatable() {
        XCTAssertEqual(AuthFlowError.invalidCredentials, .invalidCredentials)
        XCTAssertEqual(AuthFlowError.emailAlreadyExists, .emailAlreadyExists)
        XCTAssertEqual(AuthFlowError.validationError, .validationError)
        XCTAssertEqual(AuthFlowError.vaultNotFound, .vaultNotFound)
        XCTAssertEqual(AuthFlowError.vaultUnlockFailed, .vaultUnlockFailed)
        XCTAssertEqual(AuthFlowError.networkError, .networkError)
        XCTAssertEqual(AuthFlowError.unknown, .unknown)
    }
}
