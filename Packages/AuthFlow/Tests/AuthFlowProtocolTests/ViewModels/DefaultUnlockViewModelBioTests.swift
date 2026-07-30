import AuthFlowProtocol
import XCTest

@MainActor
final class DefaultUnlockViewModelBioTests: XCTestCase {
    func testBioPromptOnLockedScreen() async throws {
        let credentialStore = MockCredentialStore()
        try credentialStore.setBioEnabled(true)
        try credentialStore.savePassword("secret")
        let biometricAuthenticator = MockBiometricAuthenticator()
        biometricAuthenticator.result = .cancelled

        let viewModel = AuthFlowTestSupport.makeUnlockViewModel(
            credentialStore: credentialStore,
            biometricAuthenticator: biometricAuthenticator
        )

        await viewModel.onAppear()

        XCTAssertEqual(biometricAuthenticator.authenticateCallCount, 1)
    }

    func testSuccessfulBioUnlockProceedsToVaultUnlock() async throws {
        let credentialStore = MockCredentialStore()
        try credentialStore.saveSetup(
            email: "user@example.com",
            refreshToken: "refresh",
            vaultHeader: Data([0x01, 0x02])
        )
        try credentialStore.setBioEnabled(true)
        try credentialStore.savePassword("secret")

        let biometricAuthenticator = MockBiometricAuthenticator()
        biometricAuthenticator.result = .success
        let vaultAuthenticator = MockVaultAuthenticator()
        let vaultSession = MockVaultSession()

        let viewModel = AuthFlowTestSupport.makeUnlockViewModel(
            credentialStore: credentialStore,
            vaultAuthenticator: vaultAuthenticator,
            vaultSession: vaultSession,
            biometricAuthenticator: biometricAuthenticator
        )

        await viewModel.onAppear()

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(biometricAuthenticator.authenticateCallCount, 1)
        XCTAssertEqual(vaultAuthenticator.unlockVaultCallCount, 1)
        let establishedKeys = await vaultSession.establishedKeys
        XCTAssertNotNil(establishedKeys)
    }

    func testFailedBioShowsPasswordScreen() async throws {
        let credentialStore = MockCredentialStore()
        try credentialStore.setBioEnabled(true)
        try credentialStore.savePassword("secret")
        let biometricAuthenticator = MockBiometricAuthenticator()
        biometricAuthenticator.result = .cancelled

        let viewModel = AuthFlowTestSupport.makeUnlockViewModel(
            credentialStore: credentialStore,
            biometricAuthenticator: biometricAuthenticator
        )

        await viewModel.onAppear()

        XCTAssertEqual(viewModel.state, .passwordEntry)
    }

    func testBioDisabledShowsPasswordScreenDirectly() async {
        let credentialStore = MockCredentialStore()
        let biometricAuthenticator = MockBiometricAuthenticator()

        let viewModel = AuthFlowTestSupport.makeUnlockViewModel(
            credentialStore: credentialStore,
            biometricAuthenticator: biometricAuthenticator
        )

        await viewModel.onAppear()

        XCTAssertEqual(viewModel.state, .passwordEntry)
        XCTAssertEqual(biometricAuthenticator.authenticateCallCount, 0)
    }
}
