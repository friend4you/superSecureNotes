import AuthRepository
import AuthRepositoryProtocol
import CredentialStoreProtocol
import VaultRepositoryProtocol
import XCTest

final class AuthRepositoryAccessTokenProviderTests: XCTestCase {
    func testTokenProviderReturnsAccessTokenWhenAuthenticated() async throws {
        let repository = MockAuthRepository()
        let credentialStore = InMemoryCredentialStore()
        let session = AuthSession(
            accessToken: "token-123",
            refreshToken: "refresh",
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        await repository.setSession(session)
        let provider = AuthRepositoryAccessTokenProvider(
            repository: repository,
            credentialStore: credentialStore
        )

        let token = try await provider.accessToken()

        XCTAssertEqual(token, "token-123")
    }

    func testTokenProviderThrowsWhenNotAuthenticated() async {
        let repository = MockAuthRepository()
        let credentialStore = InMemoryCredentialStore()
        let provider = AuthRepositoryAccessTokenProvider(
            repository: repository,
            credentialStore: credentialStore
        )

        do {
            _ = try await provider.accessToken()
            XCTFail("Expected notAuthenticated error")
        } catch let error as VaultRepositoryError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRefreshAccessTokenPersistsRotatedToken() async throws {
        let repository = MockAuthRepository()
        let credentialStore = InMemoryCredentialStore()
        let session = AuthSession(
            accessToken: "token-123",
            refreshToken: "old-refresh",
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        await repository.setSession(session)
        await repository.setRefreshResult(
            AuthSession(
                accessToken: "new-access",
                refreshToken: "new-refresh",
                expiresAt: Date(timeIntervalSince1970: 1_900_000_000)
            )
        )
        let provider = AuthRepositoryAccessTokenProvider(
            repository: repository,
            credentialStore: credentialStore
        )

        let token = try await provider.refreshAccessToken()

        XCTAssertEqual(token, "new-access")
        XCTAssertEqual(credentialStore.refreshToken(), "new-refresh")
    }

    func testRefreshAccessTokenInvokesSessionExpiredHandler() async {
        let repository = MockAuthRepository()
        let credentialStore = InMemoryCredentialStore()
        let session = AuthSession(
            accessToken: "token-123",
            refreshToken: "old-refresh",
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        await repository.setSession(session)
        await repository.setRefreshError(.notAuthenticated)
        let expiredState = SessionExpiredState()
        let provider = AuthRepositoryAccessTokenProvider(
            repository: repository,
            credentialStore: credentialStore,
            onSessionExpired: { expiredState.markExpired() }
        )

        do {
            _ = try await provider.refreshAccessToken()
            XCTFail("Expected notAuthenticated")
        } catch let error as VaultRepositoryError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let isExpired = expiredState.isExpired
        XCTAssertTrue(isExpired)
    }
}

private final class SessionExpiredState: @unchecked Sendable {
    private let lock = NSLock()
    private var expired = false

    func markExpired() {
        lock.lock()
        expired = true
        lock.unlock()
    }

    var isExpired: Bool {
        lock.lock()
        defer { lock.unlock() }
        return expired
    }
}

private final class InMemoryCredentialStore: CredentialStore {
    private var storedRefreshToken: String?

    var hasLocalSetup: Bool { false }

    func markSetupComplete() throws {}

    func saveEmail(_ email: String) throws {}

    func email() -> String? { nil }

    func saveRefreshToken(_ token: String) throws {
        storedRefreshToken = token
    }

    func refreshToken() -> String? {
        storedRefreshToken
    }

    func saveVaultHeader(_ header: Data) throws {}

    func vaultHeader() -> Data? { nil }

    func bioEnabled() -> Bool { false }

    func setBioEnabled(_ enabled: Bool) throws {}

    func savePassword(_ password: String) throws {}

    func loadPasswordWithBiometrics() throws -> String {
        ""
    }

    func saveSetup(email: String, refreshToken: String, vaultHeader: Data) throws {}

    func clearAll() throws {
        storedRefreshToken = nil
    }
}

private actor MockAuthRepository: AuthRepository {
    private var session: AuthSession?
    private var refreshResult: AuthSession?
    private var refreshError: AuthRepositoryError?

    var currentSession: AuthSession? { session }
    var currentUser: User? { nil }

    func setSession(_ session: AuthSession) {
        self.session = session
    }

    func setRefreshResult(_ session: AuthSession) {
        refreshResult = session
    }

    func setRefreshError(_ error: AuthRepositoryError) {
        refreshError = error
    }

    func register(_ credentials: RegisterCredentials) async throws -> AuthSession {
        throw AuthRepositoryError.notAuthenticated
    }

    func login(_ credentials: LoginCredentials) async throws -> AuthSession {
        throw AuthRepositoryError.notAuthenticated
    }

    func logout() async throws {}

    func refreshSession() async throws -> AuthSession {
        if let refreshError {
            throw refreshError
        }
        guard let refreshResult else {
            throw AuthRepositoryError.notAuthenticated
        }
        session = refreshResult
        return refreshResult
    }

    func restoreSession(refreshToken: String) async throws -> AuthSession {
        throw AuthRepositoryError.notAuthenticated
    }

    func clearSession() async {}
}
