import AuthRepositoryProtocol
import AuthFlowProtocol
import VaultRepositoryProtocol
import XCTest

@MainActor
final class DefaultRegisterViewModelErrorTests: XCTestCase {
    func testRegisterMapsEmailAlreadyExists() async {
        let authRepository = MockAuthRepository()
        await authRepository.setRegisterError(.emailAlreadyExists)
        let viewModel = makeViewModel(authRepository: authRepository)
        viewModel.email = "user@example.com"
        viewModel.password = "secret"

        await viewModel.register()

        XCTAssertEqual(viewModel.state, .failure(.emailAlreadyExists))
    }

    func testRegisterMapsValidationError() async {
        let authRepository = MockAuthRepository()
        await authRepository.setRegisterError(.validationError("Invalid email"))
        let viewModel = makeViewModel(authRepository: authRepository)
        viewModel.email = "user@example.com"
        viewModel.password = "secret"

        await viewModel.register()

        XCTAssertEqual(viewModel.state, .failure(.validationError))
    }

    func testRegisterMapsVaultUploadFailure() async {
        let vaultRepository = MockVaultRepository()
        await vaultRepository.setWriteHeaderError(.networkError)
        let viewModel = makeViewModel(vaultRepository: vaultRepository)
        viewModel.email = "user@example.com"
        viewModel.password = "secret"

        await viewModel.register()

        XCTAssertEqual(viewModel.state, .failure(.networkError))
    }

    func testRegisterFailsAndClearsSessionWhenVaultUploadFails() async {
        let authRepository = MockAuthRepository()
        let credentialStore = MockCredentialStore()
        let noteSync = MockNoteSyncService()
        await noteSync.setUploadVaultHeaderError(VaultRepositoryError.serverError(statusCode: 500))
        let viewModel = AuthFlowTestSupport.makeRegisterViewModel(
            authRepository: authRepository,
            credentialStore: credentialStore,
            noteSync: noteSync
        )
        viewModel.email = "user@example.com"
        viewModel.password = "secret"

        await viewModel.register()

        XCTAssertEqual(viewModel.state, .failure(.unknown))
        XCTAssertFalse(credentialStore.hasLocalSetup)
        let clearSessionCallCount = await authRepository.clearSessionCallCount
        XCTAssertEqual(clearSessionCallCount, 1)
    }

    private func makeViewModel(
        authRepository: MockAuthRepository = MockAuthRepository(),
        vaultRepository: MockVaultRepository = MockVaultRepository()
    ) -> DefaultRegisterViewModel {
        AuthFlowTestSupport.makeRegisterViewModel(
            authRepository: authRepository,
            vaultRepository: vaultRepository
        )
    }
}

private extension MockNoteSyncService {
    func setUploadVaultHeaderError(_ error: Error) {
        uploadVaultHeaderError = error
    }
}

private extension MockAuthRepository {
    func setRegisterError(_ error: AuthRepositoryError) {
        registerError = error
    }
}

private extension MockVaultRepository {
    func setWriteHeaderError(_ error: VaultRepositoryError) {
        writeHeaderError = error
    }
}
