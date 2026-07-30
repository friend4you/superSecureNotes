import AuthFlowProtocol
import XCTest

final class BiometricAuthenticatorTests: XCTestCase {
    func testBiometricAuthenticatorProtocolCompiles() {
        let authenticator: any BiometricAuthenticator = MockBiometricAuthenticator()
        XCTAssertTrue(authenticator.canEvaluateBiometrics())
    }

    func testMockSatisfiesCanEvaluateBiometrics() {
        let authenticator = MockBiometricAuthenticator()
        authenticator.canEvaluate = false
        XCTAssertFalse(authenticator.canEvaluateBiometrics())

        authenticator.canEvaluate = true
        XCTAssertTrue(authenticator.canEvaluateBiometrics())
    }

    func testMockSatisfiesAuthenticate() async {
        let authenticator = MockBiometricAuthenticator()

        authenticator.result = .success
        let successResult = await authenticator.authenticate(reason: "Unlock")
        XCTAssertEqual(successResult, .success)

        authenticator.result = .cancelled
        let cancelledResult = await authenticator.authenticate(reason: "Unlock")
        XCTAssertEqual(cancelledResult, .cancelled)

        authenticator.result = .failed
        let failedResult = await authenticator.authenticate(reason: "Unlock")
        XCTAssertEqual(failedResult, .failed)

        authenticator.result = .unavailable
        let unavailableResult = await authenticator.authenticate(reason: "Unlock")
        XCTAssertEqual(unavailableResult, .unavailable)
    }

    func testBiometricAuthResultIsEquatableAndSendable() {
        let lhs: BiometricAuthResult = .success
        let rhs: BiometricAuthResult = .success
        XCTAssertEqual(lhs, rhs)

        let sendable: any Sendable = BiometricAuthResult.failed
        XCTAssertNotNil(sendable)
    }
}
