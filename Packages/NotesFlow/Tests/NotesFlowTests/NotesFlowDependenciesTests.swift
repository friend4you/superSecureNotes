import AuthRepositoryProtocol
import CryptoKit
import NavigationProtocol
import NoteRepositoryProtocol
import NotesFlow
import VaultSession
import VaultSessionProtocol
import XCTest

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
final class NotesFlowDependenciesTests: XCTestCase {
    func testNotesFlowDependenciesConformsToNotesDependencyProviding() {
        let dependencies: any NotesDependencyProviding = NotesFlowDependencies(
            authRepository: MockAuthRepository(),
            vaultSession: MockVaultSession(),
            navigator: MockNavigating(),
            noteRepository: MockNoteRepository(),
            credentialStore: NotesFlowTestMocks.credentialStore()
        )

        XCTAssertTrue(dependencies is NotesFlowDependencies)
    }

    func testMakeNoteListViewModelReturnsDefaultImplementation() {
        let dependencies = NotesFlowDependencies(
            authRepository: MockAuthRepository(),
            vaultSession: MockVaultSession(),
            navigator: MockNavigating(),
            noteRepository: MockNoteRepository(),
            credentialStore: NotesFlowTestMocks.credentialStore()
        )

        let viewModel = dependencies.makeNoteListViewModel()

        XCTAssertTrue(viewModel is DefaultNoteListViewModel)
    }

    func testMakeNoteListViewModelReturnsSameInstanceWhileVaultIsActive() {
        let dependencies = NotesFlowDependencies(
            authRepository: MockAuthRepository(),
            vaultSession: MockVaultSession(),
            navigator: MockNavigating(),
            noteRepository: MockNoteRepository(),
            credentialStore: NotesFlowTestMocks.credentialStore()
        )

        let firstViewModel = dependencies.makeNoteListViewModel()
        let secondViewModel = dependencies.makeNoteListViewModel()

        XCTAssertTrue(firstViewModel === secondViewModel)
    }

    func testMakeNoteListViewModelCreatesNewInstanceAfterVaultClears() async {
        let vaultSession = VaultSession()
        let dependencies = NotesFlowDependencies(
            authRepository: MockAuthRepository(),
            vaultSession: vaultSession,
            navigator: MockNavigating(),
            noteRepository: MockNoteRepository(),
            credentialStore: NotesFlowTestMocks.credentialStore()
        )

        let firstViewModel = dependencies.makeNoteListViewModel()
        await vaultSession.establish(
            VaultSessionKeys(udk: .init(size: .bits256), identityPrivateKey: Data(repeating: 1, count: 32))
        )
        await vaultSession.clear()
        try? await Task.sleep(nanoseconds: 50_000_000)
        let secondViewModel = dependencies.makeNoteListViewModel()

        XCTAssertFalse(firstViewModel === secondViewModel)
    }

    func testMakeNoteDetailViewModelReturnsDefaultImplementationBoundToNoteID() {
        let noteID = UUID()
        let dependencies = NotesFlowDependencies(
            authRepository: MockAuthRepository(),
            vaultSession: MockVaultSession(),
            navigator: MockNavigating(),
            noteRepository: MockNoteRepository(),
            credentialStore: NotesFlowTestMocks.credentialStore()
        )

        let viewModel = dependencies.makeNoteDetailViewModel(noteID: noteID)

        XCTAssertTrue(viewModel is DefaultNoteDetailViewModel)
        XCTAssertEqual(viewModel.noteID, noteID)
    }

    func testMakeCreateNoteViewModelReturnsDefaultImplementation() {
        let dependencies = NotesFlowDependencies(
            authRepository: MockAuthRepository(),
            vaultSession: MockVaultSession(),
            navigator: MockNavigating(),
            noteRepository: MockNoteRepository(),
            credentialStore: NotesFlowTestMocks.credentialStore()
        )

        let viewModel = dependencies.makeCreateNoteViewModel()

        XCTAssertTrue(viewModel is DefaultCreateNoteViewModel)
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
    func readNote(noteID: UUID) async throws -> Data { Data() }
    func writeNote(noteID: UUID, data: Data) async throws {}
    func deleteNote(noteID: UUID) async throws {}
}
