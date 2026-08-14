import AuthFlowDomain
import AuthFlowDomainProtocol
import AuthFlowProtocol
import XCTest

@MainActor
final class RegisterUseCaseTests: XCTestCase {
    func testRegisterRejectsEmptyCredentials() async {
        let authRepository = MockAuthRepository()
        let useCase = AuthFlowTestSupport.makeRegisterUseCase(authRepository: authRepository)

        do {
            _ = try await useCase.execute(email: "", password: "secret")
            XCTFail("Expected validation error")
        } catch {
            XCTAssertEqual(error as? AuthFlowError, .validationError(nil))
            let registerCallCount = await authRepository.registerCallCount
            XCTAssertEqual(registerCallCount, 0)
        }
    }

    func testRegisterUploadsVaultHeaderAfterCreation() async throws {
        let noteSync = MockNoteSyncService()
        let useCase = AuthFlowTestSupport.makeRegisterUseCase(noteSync: noteSync)

        _ = try await useCase.execute(email: "user@example.com", password: "secret")

        let uploadCount = await noteSync.uploadVaultHeaderCallCount
        XCTAssertEqual(uploadCount, 1)
    }

    func testRegisterClearsSessionOnUploadFailure() async {
        let authRepository = MockAuthRepository()
        let noteSync = MockNoteSyncService()
        await noteSync.setUploadVaultHeaderError(TestError.uploadFailed)
        let useCase = AuthFlowTestSupport.makeRegisterUseCase(
            authRepository: authRepository,
            noteSync: noteSync
        )

        do {
            _ = try await useCase.execute(email: "user@example.com", password: "secret")
            XCTFail("Expected upload failure")
        } catch {
            let clearCount = await authRepository.clearSessionCallCount
            XCTAssertEqual(clearCount, 1)
        }
    }

    func testRegisterReturnsWasFirstSetupOnFirstDeviceSetup() async throws {
        let credentialStore = MockCredentialStore()
        let useCase = AuthFlowTestSupport.makeRegisterUseCase(credentialStore: credentialStore)

        let result = try await useCase.execute(email: "user@example.com", password: "secret")

        XCTAssertTrue(result.wasFirstSetup)
    }

    func testRegisterPopulatesSessionPasswordCache() async throws {
        let sessionPasswordCache = SessionPasswordCache()
        let useCase = AuthFlowTestSupport.makeRegisterUseCase(sessionPasswordCache: sessionPasswordCache)

        _ = try await useCase.execute(email: "user@example.com", password: "secret")

        XCTAssertEqual(sessionPasswordCache.password(), "secret")
    }
}

private enum TestError: Error {
    case uploadFailed
}

private extension MockNoteSyncService {
    func setUploadVaultHeaderError(_ error: Error) {
        uploadVaultHeaderError = error
    }
}
