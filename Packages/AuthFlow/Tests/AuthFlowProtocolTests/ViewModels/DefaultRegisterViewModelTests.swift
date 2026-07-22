import AuthRepositoryProtocol
import AuthFlowProtocol
import XCTest

@MainActor
final class DefaultRegisterViewModelTests: XCTestCase {
    func testRegisterRejectsEmptyEmail() async {
        let authRepository = MockAuthRepository()
        let viewModel = makeViewModel(authRepository: authRepository)
        viewModel.email = ""
        viewModel.password = "secret"

        await viewModel.register()

        XCTAssertEqual(viewModel.state, .failure(.validationError))
        let registerCallCount = await authRepository.registerCallCount
        XCTAssertEqual(registerCallCount, 0)
    }

    func testRegisterRejectsEmptyPassword() async {
        let authRepository = MockAuthRepository()
        let viewModel = makeViewModel(authRepository: authRepository)
        viewModel.email = "user@example.com"
        viewModel.password = ""

        await viewModel.register()

        XCTAssertEqual(viewModel.state, .failure(.validationError))
        let registerCallCount = await authRepository.registerCallCount
        XCTAssertEqual(registerCallCount, 0)
    }

    func testRegisterTransitionsToLoadingDuringOperation() async {
        let authRepository = MockAuthRepository()
        await authRepository.setShouldSuspendOnRegister(true)
        let viewModel = makeViewModel(authRepository: authRepository)
        viewModel.email = "user@example.com"
        viewModel.password = "secret"

        let registerTask = Task {
            await viewModel.register()
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(viewModel.state, .loading)

        await authRepository.resumeRegister()
        await registerTask.value
    }

    private func makeViewModel(authRepository: MockAuthRepository) -> DefaultRegisterViewModel {
        DefaultRegisterViewModel(
            authRepository: authRepository,
            vaultRepository: MockVaultRepository(),
            vaultAuthenticator: MockVaultAuthenticator(),
            vaultSession: MockVaultSession()
        )
    }
}
