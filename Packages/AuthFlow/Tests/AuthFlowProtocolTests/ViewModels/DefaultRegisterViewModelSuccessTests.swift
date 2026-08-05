import AuthFlowProtocol
import VaultRepositoryProtocol
import XCTest

@MainActor
final class DefaultRegisterViewModelSuccessTests: XCTestCase {
    func testRegisterSucceedsAndUploadsVaultHeader() async {
        let authRepository = MockAuthRepository()
        let vaultRepository = MockVaultRepository()
        let authenticator = MockVaultAuthenticator()
        let vaultSession = MockVaultSession()
        let noteSync = MockNoteSyncService()
        let viewModel = AuthFlowTestSupport.makeRegisterViewModel(
            authRepository: authRepository,
            vaultRepository: vaultRepository,
            vaultAuthenticator: authenticator,
            vaultSession: vaultSession,
            noteSync: noteSync
        )
        viewModel.email = "user@example.com"
        viewModel.password = "secret"

        await viewModel.register()

        XCTAssertEqual(viewModel.state, .idle)
        let registerCallCount = await authRepository.registerCallCount
        let writeHeaderCallCount = await vaultRepository.writeHeaderCallCount
        let uploadCallCount = await noteSync.uploadVaultHeaderCallCount
        XCTAssertEqual(registerCallCount, 1)
        XCTAssertEqual(authenticator.createVaultCallCount, 1)
        XCTAssertEqual(writeHeaderCallCount, 1)
        XCTAssertEqual(uploadCallCount, 1)
        XCTAssertEqual(authenticator.unlockVaultCallCount, 1)
        let establishedKeys = await vaultSession.establishedKeys
        XCTAssertNotNil(establishedKeys)
    }

    func testRegisterFailsWhenVaultUploadFails() async {
        let authRepository = MockAuthRepository()
        let credentialStore = MockCredentialStore()
        let noteSync = MockNoteSyncService()
        await noteSync.setUploadVaultHeaderError(VaultRepositoryError.networkError)
        let viewModel = AuthFlowTestSupport.makeRegisterViewModel(
            authRepository: authRepository,
            credentialStore: credentialStore,
            noteSync: noteSync
        )
        viewModel.email = "user@example.com"
        viewModel.password = "secret"

        await viewModel.register()

        XCTAssertEqual(viewModel.state, .failure(.networkError))
        XCTAssertFalse(credentialStore.hasLocalSetup)
        let clearSessionCallCount = await authRepository.clearSessionCallCount
        let uploadCallCount = await noteSync.uploadVaultHeaderCallCount
        XCTAssertEqual(clearSessionCallCount, 1)
        XCTAssertEqual(uploadCallCount, 1)
    }
}

private extension MockNoteSyncService {
    func setUploadVaultHeaderError(_ error: Error) {
        uploadVaultHeaderError = error
    }
}
