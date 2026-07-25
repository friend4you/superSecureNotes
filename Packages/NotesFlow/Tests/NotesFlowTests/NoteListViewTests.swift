import AuthRepositoryProtocol
import CryptoKit
import NotesFlow
import VaultSessionProtocol
import XCTest

@MainActor
final class NoteListViewTests: XCTestCase {
    func testNoteListViewAcceptsViewModel() {
        let viewModel = DefaultNoteListViewModel(
            authRepository: MockAuthRepository(),
            vaultSession: MockVaultSession()
        )

        _ = NoteListView(viewModel: viewModel)
    }
}

private actor MockAuthRepository: AuthRepository {
    var currentSession: AuthSession? { nil }
    var currentUser: User? { nil }
    func register(_ credentials: RegisterCredentials) async throws -> AuthSession {
        AuthSession(accessToken: "", refreshToken: "", expiresAt: .distantFuture)
    }
    func login(_ credentials: LoginCredentials) async throws -> AuthSession {
        AuthSession(accessToken: "", refreshToken: "", expiresAt: .distantFuture)
    }
    func logout() async throws {}
    func refreshSession() async throws -> AuthSession {
        throw AuthRepositoryError.notAuthenticated
    }
}

private actor MockVaultSession: VaultSessionProtocol {
    var isActive: Bool { false }
    nonisolated var changes: AsyncStream<Bool> { AsyncStream { $0.finish() } }
    func establish(_ keys: VaultSessionKeys) {}
    func clear() {}
    func udk() throws -> SymmetricKey { .init(size: .bits256) }
    func identityPrivateKey() throws -> Data { Data() }
}
