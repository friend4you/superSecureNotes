import AuthFlowProtocol
import CredentialStore
import CredentialStoreProtocol
import XCTest

@testable import AuthRepository
@testable import AuthRepositoryProtocol

final class SessionRestoreTests: XCTestCase {
    private var credentialStore: KeychainCredentialStore!

    override func setUp() {
        super.setUp()
        credentialStore = KeychainCredentialStore(service: uniqueService())
    }

    override func tearDown() {
        try? credentialStore.clearAll()
        credentialStore = nil
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testLockClearsInMemoryAuthTokens() async throws {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, AuthFixtures.authSuccessJSON())
        }

        let repository = NetworkAuthRepository(
            baseURL: AuthFixtures.baseURL,
            session: .stubbed()
        )

        _ = try await repository.login(
            LoginCredentials(email: AuthFixtures.email, password: "secret-password")
        )
        let sessionBeforeLock = await repository.currentSession
        XCTAssertNotNil(sessionBeforeLock)

        await repository.clearSession()

        let sessionAfterLock = await repository.currentSession
        let userAfterLock = await repository.currentUser
        XCTAssertNil(sessionAfterLock)
        XCTAssertNil(userAfterLock)
    }

    func testLockPreservesKeychainCredentials() async throws {
        try credentialStore.saveSetup(
            email: AuthFixtures.email,
            refreshToken: "persisted-refresh-token",
            vaultHeader: Data([0x01, 0x02])
        )

        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, AuthFixtures.authSuccessJSON())
        }

        let repository = NetworkAuthRepository(
            baseURL: AuthFixtures.baseURL,
            session: .stubbed()
        )

        _ = try await repository.login(
            LoginCredentials(email: AuthFixtures.email, password: "secret-password")
        )
        await repository.clearSession()

        let sessionAfterLock = await repository.currentSession
        XCTAssertNil(sessionAfterLock)
        XCTAssertTrue(credentialStore.hasLocalSetup)
        XCTAssertEqual(credentialStore.email(), AuthFixtures.email)
        XCTAssertEqual(credentialStore.refreshToken(), "persisted-refresh-token")
    }

    func testSuccessfulRefreshRestoresInMemorySession() async throws {
        try credentialStore.saveRefreshToken("persisted-refresh-token")

        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            if request.url?.path.hasSuffix("/auth/refresh") == true {
                return (response, AuthFixtures.refreshJSON())
            }
            return (response, AuthFixtures.authSuccessJSON())
        }

        let repository = NetworkAuthRepository(
            baseURL: AuthFixtures.baseURL,
            session: .stubbed()
        )
        let helper = AuthSessionRestoreHelper()

        let sessionBeforeRestore = await repository.currentSession
        XCTAssertNil(sessionBeforeRestore)

        let session = try await helper.restoreSession(
            credentialStore: credentialStore,
            authRepository: repository
        )

        XCTAssertEqual(session.accessToken, "new-access-token")
        XCTAssertEqual(session.refreshToken, "new-refresh-token")
        let currentSession = await repository.currentSession
        XCTAssertEqual(currentSession, session)
    }

    private func uniqueService() -> String {
        "com.superSecureNotes.sessionRestore.\(UUID().uuidString)"
    }
}
