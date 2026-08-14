import AuthFlowProtocol
import NavigationProtocol
import XCTest

@MainActor
final class BiometricEnrollmentViewModelTests: XCTestCase {
    func testSkipClearsPendingFlagAndDismissesPresentation() {
        let credentialStore = MockCredentialStore()
        let sessionPasswordCache = SessionPasswordCache()
        let pendingStore = MockPendingBiometricEnrollmentStore()
        pendingStore.setPending(true)
        let navigator = MockNavigating()
        var completionCallCount = 0

        let viewModel = DefaultBiometricEnrollmentViewModel(
            credentialStore: credentialStore,
            sessionPasswordCache: sessionPasswordCache,
            pendingBiometricEnrollmentStore: pendingStore,
            navigator: navigator,
            onEnrollmentCompleted: { completionCallCount += 1 }
        )

        viewModel.skip()

        XCTAssertFalse(pendingStore.isPending)
        XCTAssertFalse(credentialStore.bioEnabled())
        XCTAssertEqual(navigator.dismissPresentationCallCount, 1)
        XCTAssertEqual(completionCallCount, 1)
    }

    func testEnableClearsPendingFlagAndDismissesPresentation() async throws {
        let credentialStore = MockCredentialStore()
        let sessionPasswordCache = SessionPasswordCache()
        sessionPasswordCache.store("secret")
        let pendingStore = MockPendingBiometricEnrollmentStore()
        pendingStore.setPending(true)
        let navigator = MockNavigating()
        var completionCallCount = 0

        let viewModel = DefaultBiometricEnrollmentViewModel(
            credentialStore: credentialStore,
            sessionPasswordCache: sessionPasswordCache,
            pendingBiometricEnrollmentStore: pendingStore,
            navigator: navigator,
            onEnrollmentCompleted: { completionCallCount += 1 }
        )

        try await viewModel.enableBiometrics()

        XCTAssertFalse(pendingStore.isPending)
        XCTAssertTrue(credentialStore.bioEnabled())
        XCTAssertEqual(try credentialStore.loadPasswordWithBiometrics(), "secret")
        XCTAssertEqual(navigator.dismissPresentationCallCount, 1)
        XCTAssertEqual(completionCallCount, 1)
    }

    func testEnableStoresCachedPasswordInKeychain() async throws {
        let credentialStore = MockCredentialStore()
        let sessionPasswordCache = SessionPasswordCache()
        sessionPasswordCache.store("cached-secret")
        let pendingStore = MockPendingBiometricEnrollmentStore()
        let navigator = MockNavigating()

        let viewModel = DefaultBiometricEnrollmentViewModel(
            credentialStore: credentialStore,
            sessionPasswordCache: sessionPasswordCache,
            pendingBiometricEnrollmentStore: pendingStore,
            navigator: navigator
        )

        try await viewModel.enableBiometrics()

        XCTAssertEqual(try credentialStore.loadPasswordWithBiometrics(), "cached-secret")
    }
}
