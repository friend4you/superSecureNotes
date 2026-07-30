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
