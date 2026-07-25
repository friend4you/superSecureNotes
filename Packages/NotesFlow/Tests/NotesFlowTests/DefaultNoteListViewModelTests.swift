import AuthRepositoryProtocol
import CryptoKit
import NavigationProtocol
import NotesFlow
import VaultSessionProtocol
import XCTest

@MainActor
final class DefaultNoteListViewModelTests: XCTestCase {
    func testLogoutClearsAuthAndVaultSession() async throws {
        let authRepository = MockAuthRepository()
        let vaultSession = MockVaultSession()
        _ = try await authRepository.login(
            LoginCredentials(email: "user@example.com", password: "secret")
        )
        await vaultSession.establish(
            VaultSessionKeys(
                udk: .init(size: .bits256),
                identityPrivateKey: Data(repeating: 0x01, count: 32)
            )
        )

        let viewModel = DefaultNoteListViewModel(
            authRepository: authRepository,
            vaultSession: vaultSession
        )
        await viewModel.logout()

        let currentSession = await authRepository.currentSession
        let isActive = await vaultSession.isActive
        XCTAssertNil(currentSession)
        XCTAssertFalse(isActive)
    }
}

private actor MockAuthRepository: AuthRepository {
    private var session: AuthSession?

    var currentSession: AuthSession? { session }
    var currentUser: User? { nil }

    func register(_ credentials: RegisterCredentials) async throws -> AuthSession {
        session = AuthSession(
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: .distantFuture
        )
        return session!
    }

    func login(_ credentials: LoginCredentials) async throws -> AuthSession {
        session = AuthSession(
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: .distantFuture
        )
        return session!
    }

    func logout() async throws {
        session = nil
    }

    func refreshSession() async throws -> AuthSession {
        guard let session else {
            throw AuthRepositoryError.notAuthenticated
        }
        return session
    }
}

private actor MockVaultSession: VaultSessionProtocol {
    private var keys: VaultSessionKeys?

    var isActive: Bool { keys != nil }

    nonisolated var changes: AsyncStream<Bool> {
        AsyncStream { $0.finish() }
    }

    func establish(_ keys: VaultSessionKeys) {
        self.keys = keys
    }

    func clear() {
        keys = nil
    }

    func udk() throws -> SymmetricKey {
        guard let keys else {
            throw VaultSessionError.notActive
        }
        return keys.udk
    }

    func identityPrivateKey() throws -> Data {
        guard let keys else {
            throw VaultSessionError.notActive
        }
        return keys.identityPrivateKey
    }
}
