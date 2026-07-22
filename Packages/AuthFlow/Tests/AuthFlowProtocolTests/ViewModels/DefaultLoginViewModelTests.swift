import AuthRepositoryProtocol
import AuthFlowProtocol
import XCTest

@MainActor
final class DefaultLoginViewModelTests: XCTestCase {
    func testLoginRejectsEmptyEmail() async {
        let authRepository = MockAuthRepository()
        let viewModel = makeViewModel(authRepository: authRepository)
        viewModel.email = ""
        viewModel.password = "secret"

        await viewModel.login()

        XCTAssertEqual(viewModel.state, .failure(.validationError))
        let loginCallCount = await authRepository.loginCallCount
        XCTAssertEqual(loginCallCount, 0)
    }

    func testLoginRejectsEmptyPassword() async {
        let authRepository = MockAuthRepository()
        let viewModel = makeViewModel(authRepository: authRepository)
        viewModel.email = "user@example.com"
        viewModel.password = ""

        await viewModel.login()

        XCTAssertEqual(viewModel.state, .failure(.validationError))
        let loginCallCount = await authRepository.loginCallCount
        XCTAssertEqual(loginCallCount, 0)
    }

    func testLoginTransitionsToLoadingDuringOperation() async {
        let authRepository = MockAuthRepository()
        await authRepository.setShouldSuspendOnLogin(true)
        let viewModel = makeViewModel(authRepository: authRepository)
        viewModel.email = "user@example.com"
        viewModel.password = "secret"

        let loginTask = Task {
            await viewModel.login()
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(viewModel.state, .loading)

        await authRepository.resumeLogin()
        await loginTask.value
    }

    private func makeViewModel(authRepository: MockAuthRepository) -> DefaultLoginViewModel {
        DefaultLoginViewModel(
            authRepository: authRepository,
            vaultRepository: MockVaultRepository(),
            vaultAuthenticator: MockVaultAuthenticator(),
            vaultSession: MockVaultSession()
        )
    }
}
