import AuthRepositoryProtocol
import CryptoKit
import Navigation
import NavigationProtocol
import NoteRepositoryProtocol
import NotesFlowRoutes
import SecureCrypto
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

    private(set) var makeNoteListViewModelCallCount = 0
    private(set) var makeNoteDetailViewModelCallCount = 0
    private(set) var makeCreateNoteViewModelCallCount = 0
    private(set) var lastNoteDetailViewModelNoteID: UUID?

    func makeNoteListViewModel() -> DefaultNoteListViewModel {
        makeNoteListViewModelCallCount += 1
        return DefaultNoteListViewModel(
            authRepository: MockAuthRepository(),
            vaultSession: MockVaultSession(),
            noteRepository: noteRepository,
            navigator: MockNavigating(),
            credentialStore: NotesFlowTestMocks.credentialStore()
        )
    }

    func makeNoteDetailViewModel(noteID: UUID) -> DefaultNoteDetailViewModel {
        makeNoteDetailViewModelCallCount += 1
        lastNoteDetailViewModelNoteID = noteID
        return DefaultNoteDetailViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            vaultSession: MockVaultSession(),
            navigator: MockNavigating()
        )
    }

    func makeCreateNoteViewModel() -> DefaultCreateNoteViewModel {
        makeCreateNoteViewModelCallCount += 1
        return DefaultCreateNoteViewModel(
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

    func restoreSession(refreshToken: String) async throws -> AuthSession {
        throw AuthRepositoryError.notAuthenticated
    }

    func clearSession() async {}
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
    func readNote(noteID: UUID) async throws -> StoredNote {
        StoredNote(
            metadata: NoteMetadata(
                noteID: noteID,
                title: "",
                createdAt: 0,
                updatedAt: 0,
                attachmentCount: 0,
                attachmentsTotalSize: 0
            ),
            wrappedFEK: Data(),
            encryptedPayload: Data([0x01]),
            syncState: .pendingSync
        )
    }
    func writeNote(_ note: StoredNote) async throws {}
    func deleteNote(noteID: UUID) async throws {}
}

@MainActor
final class NotesNavigationTests: XCTestCase {
    func testViewForListBuildsNoteListView() {
        let deps = MockNotesDependencies()

        _ = NotesNavigation.listView(deps: deps)

        XCTAssertEqual(deps.makeNoteListViewModelCallCount, 1)
        XCTAssertEqual(deps.makeNoteDetailViewModelCallCount, 0)
        XCTAssertEqual(deps.makeCreateNoteViewModelCallCount, 0)
    }

    func testViewForListUsesDependencyProviding() {
        let deps = MockNotesDependencies()

        _ = NotesNavigation.view(for: .list, deps: deps)

        XCTAssertEqual(deps.makeNoteListViewModelCallCount, 1)
    }

    func testDetailViewBuildsNoteDetailView() {
        let noteID = UUID()
        let deps = MockNotesDependencies()

        _ = NotesNavigation.detailView(noteID: noteID, deps: deps)

        XCTAssertEqual(deps.makeNoteDetailViewModelCallCount, 1)
        XCTAssertEqual(deps.lastNoteDetailViewModelNoteID, noteID)
        XCTAssertEqual(deps.makeCreateNoteViewModelCallCount, 0)
    }

    func testCreateViewBuildsCreateNoteView() {
        let deps = MockNotesDependencies()

        _ = NotesNavigation.createView(deps: deps)

        XCTAssertEqual(deps.makeCreateNoteViewModelCallCount, 1)
        XCTAssertEqual(deps.makeNoteDetailViewModelCallCount, 0)
    }

    func testViewForDetailUsesDependencyProviding() {
        let noteID = UUID()
        let deps = MockNotesDependencies()

        _ = NotesNavigation.view(for: .detail(noteID: noteID), deps: deps)

        XCTAssertEqual(deps.makeNoteDetailViewModelCallCount, 1)
        XCTAssertEqual(deps.lastNoteDetailViewModelNoteID, noteID)
    }

    func testViewForCreateUsesDependencyProviding() {
        let deps = MockNotesDependencies()

        _ = NotesNavigation.view(for: .create, deps: deps)

        XCTAssertEqual(deps.makeCreateNoteViewModelCallCount, 1)
    }

    func testRegisterNotesRoutesResolvesAllRouteCases() {
        let deps = MockNotesDependencies()
        let registry = RouteRegistry(assertOnUnregisteredRoutes: false)
        registry.registerNotesRoutes(deps: deps)

        let noteID = UUID()
        _ = registry.view(for: NotesRoute.list)
        _ = registry.view(for: NotesRoute.detail(noteID: noteID))
        _ = registry.view(for: NotesRoute.create)

        XCTAssertTrue(registry.isRegistered(NotesRoute.self))
        XCTAssertEqual(deps.makeNoteListViewModelCallCount, 1)
        XCTAssertEqual(deps.makeNoteDetailViewModelCallCount, 1)
        XCTAssertEqual(deps.lastNoteDetailViewModelNoteID, noteID)
        XCTAssertEqual(deps.makeCreateNoteViewModelCallCount, 1)
    }
}
