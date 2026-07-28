import AuthRepositoryProtocol
import CryptoKit
import NavigationProtocol
import NoteRepositoryProtocol
import NotesFlowRoutes
import VaultSessionProtocol
import XCTest

@testable import NotesFlow

@MainActor
private final class MockNavigating: Navigating {
    func setRoot<R: Route>(_ route: R) {}
    func push<R: Route>(_ route: R) {}
    func present<R: Route>(_ route: R, style: RoutePresentation) {}
    func pop() {}
    func popToRoot() {}
    func dismissPresentation() {}
}

@MainActor
private final class MockNotesDependencies: NotesDependencyProviding {
    private let noteRepository = MockNoteRepository()

    func makeNoteListViewModel() -> DefaultNoteListViewModel {
        DefaultNoteListViewModel(
            authRepository: MockAuthRepository(),
            vaultSession: MockVaultSession(),
            noteRepository: noteRepository,
            navigator: MockNavigating()
        )
    }

    func makeNoteDetailViewModel(noteID: UUID) -> DefaultNoteDetailViewModel {
        DefaultNoteDetailViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            vaultSession: MockVaultSession(),
            navigator: MockNavigating()
        )
    }

    func makeCreateNoteViewModel() -> DefaultCreateNoteViewModel {
        DefaultCreateNoteViewModel(
            noteRepository: noteRepository,
            vaultSession: MockVaultSession(),
            navigator: MockNavigating()
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

private actor MockNoteRepository: NoteRepository {
    func listNotes() async throws -> [NoteSummary] { [] }
    func readNote(noteID: UUID) async throws -> Data { Data() }
    func writeNote(noteID: UUID, data: Data) async throws {}
    func deleteNote(noteID: UUID) async throws {}
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
