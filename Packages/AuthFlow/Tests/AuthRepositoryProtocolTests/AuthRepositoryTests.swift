import XCTest

@testable import AuthRepositoryProtocol

final class AuthRepositoryTests: XCTestCase {
    func testMockActorSatisfiesContract() async throws {
        let repository = MockAuthRepository()
        let initialSession = await repository.currentSession
        let initialUser = await repository.currentUser
        XCTAssertNil(initialSession)
        XCTAssertNil(initialUser)

        let session = AuthSession(
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        await repository.setAuthenticated(
            user: User(id: "id", email: "user@example.com", createdAt: Date(timeIntervalSince1970: 1)),
            session: session
        )

        let currentSession = await repository.currentSession
        let currentUser = await repository.currentUser
        XCTAssertEqual(currentSession, session)
        XCTAssertEqual(currentUser?.email, "user@example.com")

        try await repository.logout()
        let clearedSession = await repository.currentSession
        let clearedUser = await repository.currentUser
        XCTAssertNil(clearedSession)
        XCTAssertNil(clearedUser)
    }
}

private actor MockAuthRepository: AuthRepository {
    private var session: AuthSession?
    private var user: User?

    var currentSession: AuthSession? { session }
    var currentUser: User? { user }

    func setAuthenticated(user: User, session: AuthSession) {
        self.user = user
        self.session = session
    }

    func register(_ credentials: RegisterCredentials) async throws -> AuthSession {
        AuthSession(accessToken: "access", refreshToken: "refresh", expiresAt: Date())
    }

    func login(_ credentials: LoginCredentials) async throws -> AuthSession {
        AuthSession(accessToken: "access", refreshToken: "refresh", expiresAt: Date())
    }

    func logout() async throws {
        session = nil
        user = nil
    }

    func refreshSession() async throws -> AuthSession {
        guard let session else {
            throw AuthRepositoryError.notAuthenticated
        }
        return session
    }
}
