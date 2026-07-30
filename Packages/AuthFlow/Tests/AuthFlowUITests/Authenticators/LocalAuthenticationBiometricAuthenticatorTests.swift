import AuthFlowProtocol
import XCTest

@testable import AuthFlowUI

final class LocalAuthenticationBiometricAuthenticatorTests: XCTestCase {
    func testConformsToBiometricAuthenticatorProtocol() {
        let authenticator: any BiometricAuthenticator = LocalAuthenticationBiometricAuthenticator()
        XCTAssertNotNil(authenticator)
    }

    func testWrapsLAContextBehindInjectableSeam() async {
        final class ReasonBox: @unchecked Sendable {
            var value: String?
        }

        let reasonBox = ReasonBox()
        let contextFactory = LAContextEvaluating(
            canEvaluateBiometrics: { true },
            evaluatePolicy: { reason in
                reasonBox.value = reason
                return .success
            }
        )
        let authenticator = LocalAuthenticationBiometricAuthenticator(contextFactory: contextFactory)

        XCTAssertTrue(authenticator.canEvaluateBiometrics())
        let result = await authenticator.authenticate(reason: "Unlock vault")
        XCTAssertEqual(result, .success)
        XCTAssertEqual(reasonBox.value, "Unlock vault")
    }

    func testReturnsUnavailableWhenBiometricsCannotBeEvaluated() async {
        let contextFactory = LAContextEvaluating(
            canEvaluateBiometrics: { false },
            evaluatePolicy: { _ in .unavailable }
        )
        let authenticator = LocalAuthenticationBiometricAuthenticator(contextFactory: contextFactory)

        XCTAssertFalse(authenticator.canEvaluateBiometrics())
        let result = await authenticator.authenticate(reason: "Unlock vault")
        XCTAssertEqual(result, .unavailable)
    }

    func testReturnsCancelledWhenEvaluationIsCancelled() async {
        let contextFactory = LAContextEvaluating(
            canEvaluateBiometrics: { true },
            evaluatePolicy: { _ in .cancelled }
        )
        let authenticator = LocalAuthenticationBiometricAuthenticator(contextFactory: contextFactory)

        let result = await authenticator.authenticate(reason: "Unlock vault")
        XCTAssertEqual(result, .cancelled)
    }

    func testReturnsFailedWhenEvaluationFails() async {
        let contextFactory = LAContextEvaluating(
            canEvaluateBiometrics: { true },
            evaluatePolicy: { _ in .failed }
        )
        let authenticator = LocalAuthenticationBiometricAuthenticator(contextFactory: contextFactory)

        let result = await authenticator.authenticate(reason: "Unlock vault")
        XCTAssertEqual(result, .failed)
    }
}
