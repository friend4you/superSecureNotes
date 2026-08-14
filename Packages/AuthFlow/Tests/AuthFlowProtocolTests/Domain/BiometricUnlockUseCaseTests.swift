import AuthFlowDomain
import XCTest

@MainActor
final class BiometricUnlockUseCaseTests: XCTestCase {
    func testSuccessReturnsPassword() async {
        let credentialStore = MockCredentialStore()
        try? credentialStore.setBioEnabled(true)
        try? credentialStore.savePassword("secret")
        let biometricAuthenticator = MockBiometricAuthenticator()
        biometricAuthenticator.result = .success
        let useCase = AuthFlowTestSupport.makeBiometricUnlockUseCase(
            credentialStore: credentialStore,
            biometricAuthenticator: biometricAuthenticator
        )

        let result = await useCase.execute()

        XCTAssertEqual(result, .success(password: "secret"))
    }

    func testUnavailableFallsBackToPasswordEntry() async {
        let credentialStore = MockCredentialStore()
        let biometricAuthenticator = MockBiometricAuthenticator()
        biometricAuthenticator.canEvaluate = false
        let useCase = AuthFlowTestSupport.makeBiometricUnlockUseCase(
            credentialStore: credentialStore,
            biometricAuthenticator: biometricAuthenticator
        )

        let result = await useCase.execute()

        XCTAssertEqual(result, .passwordEntryRequired)
        XCTAssertEqual(biometricAuthenticator.authenticateCallCount, 0)
    }

    func testCancelledFallsBackToPasswordEntry() async {
        let credentialStore = MockCredentialStore()
        try? credentialStore.setBioEnabled(true)
        let biometricAuthenticator = MockBiometricAuthenticator()
        biometricAuthenticator.result = .cancelled
        let useCase = AuthFlowTestSupport.makeBiometricUnlockUseCase(
            credentialStore: credentialStore,
            biometricAuthenticator: biometricAuthenticator
        )

        let result = await useCase.execute()

        XCTAssertEqual(result, .passwordEntryRequired)
    }
}
