import AuthFlowDomain
import AuthFlowDomainProtocol
import AuthFlowProtocol
import AuthRepositoryProtocol
import XCTest

@MainActor
final class LoginUseCaseTests: XCTestCase {
    func testLoginRejectsEmptyCredentials() async {
        let authRepository = MockAuthRepository()
        let useCase = AuthFlowTestSupport.makeLoginUseCase(authRepository: authRepository)

        do {
            _ = try await useCase.execute(email: "", password: "secret")
            XCTFail("Expected validation error")
        } catch {
            XCTAssertEqual(error as? AuthFlowError, .validationError(nil))
            let loginCallCount = await authRepository.loginCallCount
            XCTAssertEqual(loginCallCount, 0)
        }
    }

    func testLoginRejectsOfflineFirstSetup() async {
        let authRepository = MockAuthRepository()
        let credentialStore = MockCredentialStore()
        let useCase = AuthFlowTestSupport.makeLoginUseCase(
            authRepository: authRepository,
            credentialStore: credentialStore,
            networkReachability: MockNetworkReachability(isOnline: false)
        )

        do {
            _ = try await useCase.execute(email: "user@example.com", password: "secret")
            XCTFail("Expected network required error")
        } catch {
            XCTAssertEqual(error as? AuthFlowError, .networkRequired)
            let loginCallCount = await authRepository.loginCallCount
            XCTAssertEqual(loginCallCount, 0)
        }
    }

    func testLoginReturnsWasFirstSetupOnFirstDeviceSetup() async throws {
        let credentialStore = MockCredentialStore()
        let useCase = AuthFlowTestSupport.makeLoginUseCase(credentialStore: credentialStore)

        let result = try await useCase.execute(email: "user@example.com", password: "secret")

        XCTAssertTrue(result.wasFirstSetup)
        XCTAssertTrue(credentialStore.hasLocalSetup)
    }

    func testLoginMapsInvalidCredentials() async {
        let authRepository = MockAuthRepository()
        await authRepository.setLoginError(.invalidCredentials)
        let useCase = AuthFlowTestSupport.makeLoginUseCase(authRepository: authRepository)

        do {
            _ = try await useCase.execute(email: "user@example.com", password: "secret")
            XCTFail("Expected invalid credentials error")
        } catch {
            XCTAssertEqual(error as? AuthFlowError, .invalidCredentials)
        }
    }

    func testLoginPullsRemoteHeaderAndCatalogs() async throws {
        let noteSync = MockNoteSyncService()
        await noteSync.setLocalVaultHeaderExists(false)
        let useCase = AuthFlowTestSupport.makeLoginUseCase(noteSync: noteSync)

        _ = try await useCase.execute(email: "user@example.com", password: "secret")

        let pullNotesCount = await noteSync.pullRemoteNotesCatalogCallCount
        let pullSharedCount = await noteSync.pullRemoteSharedCatalogCallCount
        XCTAssertEqual(pullNotesCount, 1)
        XCTAssertEqual(pullSharedCount, 1)
    }
}

private extension MockAuthRepository {
    func setLoginError(_ error: AuthRepositoryError) {
        loginError = error
    }
}

private extension MockNoteSyncService {
    func setLocalVaultHeaderExists(_ exists: Bool) {
        localVaultHeaderExists = exists
    }
}
