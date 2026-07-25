import AuthRepositoryProtocol
import CryptoKit
import NotesFlowRoutes
import VaultSessionProtocol
import XCTest

@testable import NotesFlow

@MainActor
private final class MockNotesDependencies: NotesDependencyProviding {
    func makeNoteListViewModel() -> DefaultNoteListViewModel {
        DefaultNoteListViewModel(
            authRepository: MockAuthRepository(),
            vaultSession: MockVaultSession()
        )
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

@MainActor
final class NotesNavigationTests: XCTestCase {
    func testViewForListBuildsNoteListView() {
        let deps = MockNotesDependencies()

        _ = NotesNavigation.listView(deps: deps)
    }

    func testViewForListUsesDependencyProviding() {
        let deps = MockNotesDependencies()

        _ = NotesNavigation.view(for: .list, deps: deps)
    }
}
