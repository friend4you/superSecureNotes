import AuthFlowProtocol
import NavigationProtocol
import XCTest

@MainActor
final class BiometricEnrollmentViewModelTests: XCTestCase {
    func testSkipDismissesPresentation() {
        let credentialStore = MockCredentialStore()
        let navigator = MockNavigating()

        let viewModel = DefaultBiometricEnrollmentViewModel(
            credentialStore: credentialStore,
            navigator: navigator
        )

        viewModel.skip()

        XCTAssertFalse(credentialStore.bioEnabled())
        XCTAssertEqual(navigator.dismissPresentationCallCount, 1)
    }

    func testEnableBiometricsSavesPasswordAndDismissesPresentation() async throws {
        let credentialStore = MockCredentialStore()
        let navigator = MockNavigating()

        let viewModel = DefaultBiometricEnrollmentViewModel(
            credentialStore: credentialStore,
            navigator: navigator
        )

        try await viewModel.enableBiometrics(password: "secret")

        XCTAssertTrue(credentialStore.bioEnabled())
        XCTAssertEqual(try credentialStore.loadPasswordWithBiometrics(), "secret")
        XCTAssertEqual(navigator.dismissPresentationCallCount, 1)
    }
}
