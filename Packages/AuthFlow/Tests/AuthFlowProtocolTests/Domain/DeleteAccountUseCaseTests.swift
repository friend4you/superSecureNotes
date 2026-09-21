import AuthFlowDomain
import AuthFlowDomainProtocol
import AuthFlowProtocol
import AuthRepositoryProtocol
import XCTest

@MainActor
final class DeleteAccountUseCaseTests: XCTestCase {
    func testSuccessfulDeleteCallsRepositoryThenReset() async throws {
        let authRepository = MockAuthRepository()
        var resetCallCount = 0
        let useCase = DefaultDeleteAccountUseCase(
            authRepository: authRepository,
            performFullReset: {
                resetCallCount += 1
            }
        )

        try await useCase.execute(password: "secret-password")

        let deleteCallCount = await authRepository.deleteAccountCallCount
        XCTAssertEqual(deleteCallCount, 1)
        XCTAssertEqual(resetCallCount, 1)
    }

    func testFailedDeletePreservesStateAndSkipsReset() async {
        let authRepository = MockAuthRepository()
        await authRepository.setDeleteAccountError(.invalidCredentials)
        var resetCallCount = 0
        let useCase = DefaultDeleteAccountUseCase(
            authRepository: authRepository,
            performFullReset: {
                resetCallCount += 1
            }
        )

        do {
            try await useCase.execute(password: "wrong-password")
            XCTFail("Expected invalid credentials error")
        } catch {
            XCTAssertEqual(error as? AuthFlowError, .invalidCredentials)
        }

        let deleteCallCount = await authRepository.deleteAccountCallCount
        XCTAssertEqual(deleteCallCount, 1)
        XCTAssertEqual(resetCallCount, 0)
    }
}
