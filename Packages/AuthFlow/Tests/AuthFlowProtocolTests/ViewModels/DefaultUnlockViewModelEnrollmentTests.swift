import AuthFlowProtocol
import AuthFlowRoutes
import XCTest

@MainActor
final class DefaultUnlockViewModelEnrollmentTests: XCTestCase {
    func testUnlockPresentsEnrollmentWhenPending() async throws {
        let navigator = MockNavigating()
        let pendingStore = MockPendingBiometricEnrollmentStore()
        pendingStore.setPending(true)
        let credentialStore = MockCredentialStore()
        try credentialStore.saveSetup(
            email: "user@example.com",
            refreshToken: "refresh",
            vaultHeader: Data([0x01])
        )
        let viewModel = AuthFlowTestSupport.makeUnlockViewModel(
            credentialStore: credentialStore,
            navigator: navigator,
            pendingBiometricEnrollmentStore: pendingStore
        )
        viewModel.password = "secret"

        await viewModel.unlockWithPassword()

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(navigator.presentedRoutes.count, 1)
        XCTAssertEqual(navigator.presentedRoutes.first?.route, AnyHashable(AuthRoute.biometricEnrollment))
    }

    func testUnlockDoesNotPresentEnrollmentWhenNotPending() async throws {
        let navigator = MockNavigating()
        let pendingStore = MockPendingBiometricEnrollmentStore()
        let credentialStore = MockCredentialStore()
        try credentialStore.saveSetup(
            email: "user@example.com",
            refreshToken: "refresh",
            vaultHeader: Data([0x01])
        )
        let viewModel = AuthFlowTestSupport.makeUnlockViewModel(
            credentialStore: credentialStore,
            navigator: navigator,
            pendingBiometricEnrollmentStore: pendingStore
        )
        viewModel.password = "secret"

        await viewModel.unlockWithPassword()

        XCTAssertTrue(navigator.presentedRoutes.isEmpty)
    }
}
