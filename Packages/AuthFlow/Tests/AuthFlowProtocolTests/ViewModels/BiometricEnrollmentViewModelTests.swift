import AuthFlowProtocol
import XCTest

@MainActor
final class BiometricEnrollmentViewModelTests: XCTestCase {
    func testUserCanSkipEnrollment() {
        let credentialStore = MockCredentialStore()
        var didComplete = false

        let viewModel = DefaultBiometricEnrollmentViewModel(
            credentialStore: credentialStore,
            onComplete: { didComplete = true }
        )

        viewModel.skip()

        XCTAssertFalse(credentialStore.bioEnabled())
        XCTAssertTrue(didComplete)
    }

    func testEnableBiometricsSavesPasswordAndSetsFlag() async throws {
        let credentialStore = MockCredentialStore()
        var didComplete = false

        let viewModel = DefaultBiometricEnrollmentViewModel(
            credentialStore: credentialStore,
            onComplete: { didComplete = true }
        )

        try await viewModel.enableBiometrics(password: "secret")

        XCTAssertTrue(credentialStore.bioEnabled())
        XCTAssertEqual(try credentialStore.loadPasswordWithBiometrics(), "secret")
        XCTAssertTrue(didComplete)
    }
}
