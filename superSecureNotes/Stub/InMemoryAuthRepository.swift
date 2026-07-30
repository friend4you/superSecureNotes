import AuthRepositoryProtocol
import Foundation

#if DEBUG

actor InMemoryAuthRepository: AuthRepository {
    private var session: AuthSession?
    private var user: User?

    var currentSession: AuthSession? { session }
    var currentUser: User? { user }

    func register(_ credentials: RegisterCredentials) async throws -> AuthSession {
        storeSession(for: credentials.email)
    }

    func login(_ credentials: LoginCredentials) async throws -> AuthSession {
        storeSession(for: credentials.email)
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

    func restoreSession(refreshToken: String) async throws -> AuthSession {
        let newSession = AuthSession(
            accessToken: "stub-access-token",
            refreshToken: refreshToken,
            expiresAt: .distantFuture
        )
        session = newSession
        return newSession
    }

    func clearSession() async {
        session = nil
        user = nil
    }

    private func storeSession(for email: String) -> AuthSession {
        let newSession = AuthSession(
            accessToken: "stub-access-token",
            refreshToken: "stub-refresh-token",
            expiresAt: .distantFuture
        )
        session = newSession
        user = User(
            id: UUID().uuidString,
            email: email,
            createdAt: Date()
        )
        return newSession
    }
}

#endif
