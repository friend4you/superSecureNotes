import AuthFlowProtocol
import AuthRepositoryProtocol
import CredentialStoreProtocol
import XCTest

final class AuthSessionRestorePersistenceTests: XCTestCase {
    func testUnlockRestorePersistsRotatedToken() async throws {
        let credentialStore = RestorePersistenceMockCredentialStore(refreshToken: "stored-refresh")
        let authRepository = RestorePersistenceMockAuthRepository()
        await authRepository.setRestoreResult(
            AuthSession(
                accessToken: "restored-access",
                refreshToken: "rotated-refresh",
                expiresAt: Date(timeIntervalSince1970: 1_900_000_000)
            )
        )
        let helper = AuthSessionRestoreHelper()

        let session = try await helper.restoreSession(
            credentialStore: credentialStore,
            authRepository: authRepository
        )

        XCTAssertEqual(session.refreshToken, "rotated-refresh")
        XCTAssertEqual(credentialStore.savedRefreshToken, "rotated-refresh")
    }
}

private final class RestorePersistenceMockCredentialStore: CredentialStore {
    let initialRefreshToken: String?
    private(set) var savedRefreshToken: String?

    init(refreshToken: String?) {
        initialRefreshToken = refreshToken
        savedRefreshToken = refreshToken
    }

    var hasLocalSetup: Bool { true }

    func markSetupComplete() throws {}

    func saveEmail(_ email: String) throws {}

    func email() -> String? { "user@example.com" }

    func saveRefreshToken(_ token: String) throws {
        savedRefreshToken = token
    }

    func refreshToken() -> String? {
        savedRefreshToken ?? initialRefreshToken
    }

    func saveVaultHeader(_ header: Data) throws {}

    func vaultHeader() -> Data? { Data([0x01]) }

    func bioEnabled() -> Bool { false }

    func setBioEnabled(_ enabled: Bool) throws {}

    func savePassword(_ password: String) throws {}

    func loadPasswordWithBiometrics() throws -> String { "" }

    func saveSetup(email: String, refreshToken: String, vaultHeader: Data) throws {}

    func clearAll() throws {
        savedRefreshToken = nil
    }
}

private actor RestorePersistenceMockAuthRepository: AuthRepository {
    private var restoreResult: AuthSession?

    var currentSession: AuthSession? { nil }
    var currentUser: User? { nil }

    func setRestoreResult(_ session: AuthSession) {
        restoreResult = session
    }

    func register(_ credentials: RegisterCredentials) async throws -> AuthSession {
        throw AuthRepositoryError.notAuthenticated
    }

    func login(_ credentials: LoginCredentials) async throws -> AuthSession {
        throw AuthRepositoryError.notAuthenticated
    }

    func logout() async throws {}

    func refreshSession() async throws -> AuthSession {
        throw AuthRepositoryError.notAuthenticated
    }

    func restoreSession(refreshToken: String) async throws -> AuthSession {
        guard let restoreResult else {
            throw AuthRepositoryError.notAuthenticated
        }
        return restoreResult
    }

    func clearSession() async {}
}
