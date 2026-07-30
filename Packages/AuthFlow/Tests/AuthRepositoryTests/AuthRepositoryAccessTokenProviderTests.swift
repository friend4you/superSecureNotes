import AuthRepository
import AuthRepositoryProtocol
import VaultRepositoryProtocol
import XCTest

final class AuthRepositoryAccessTokenProviderTests: XCTestCase {
    func testTokenProviderReturnsAccessTokenWhenAuthenticated() async throws {
        let repository = MockAuthRepository()
        let session = AuthSession(
            accessToken: "token-123",
            refreshToken: "refresh",
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        await repository.setSession(session)
        let provider = AuthRepositoryAccessTokenProvider(repository: repository)

        let token = try await provider.accessToken()

        XCTAssertEqual(token, "token-123")
    }

    func testTokenProviderThrowsWhenNotAuthenticated() async {
        let repository = MockAuthRepository()
        let provider = AuthRepositoryAccessTokenProvider(repository: repository)

        do {
            _ = try await provider.accessToken()
            XCTFail("Expected notAuthenticated error")
        } catch let error as VaultRepositoryError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private actor MockAuthRepository: AuthRepository {
    private var session: AuthSession?

    var currentSession: AuthSession? { session }
    var currentUser: User? { nil }

    func setSession(_ session: AuthSession) {
        self.session = session
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
        throw AuthRepositoryError.notAuthenticated
    }

    func clearSession() async {}
}
