import AuthRepositoryProtocol
import CryptoKit
import NavigationProtocol
import NoteRepositoryProtocol
import NotesFlow
import SecureCrypto
import VaultSession
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
final class NotesFlowDependenciesTests: XCTestCase {
    func testNotesFlowDependenciesConformsToNotesDependencyProviding() {
        let dependencies: any NotesDependencyProviding = NotesFlowDependencies(
            authRepository: MockAuthRepository(),
            vaultSession: MockVaultSession(),
            navigator: MockNavigating(),
            noteRepository: MockNoteRepository(),
            credentialStore: NotesFlowTestMocks.credentialStore(),
            performLogout: NotesFlowTestMocks.noopLogout
        )

        XCTAssertTrue(dependencies is NotesFlowDependencies)
    }

    func testMakeNoteListViewModelReturnsDefaultImplementation() {
        let dependencies = NotesFlowDependencies(
            authRepository: MockAuthRepository(),
            vaultSession: MockVaultSession(),
            navigator: MockNavigating(),
            noteRepository: MockNoteRepository(),
            credentialStore: NotesFlowTestMocks.credentialStore(),
            performLogout: NotesFlowTestMocks.noopLogout
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
            credentialStore: NotesFlowTestMocks.credentialStore(),
            performLogout: NotesFlowTestMocks.noopLogout
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
            credentialStore: NotesFlowTestMocks.credentialStore(),
            performLogout: NotesFlowTestMocks.noopLogout
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
            credentialStore: NotesFlowTestMocks.credentialStore(),
            performLogout: NotesFlowTestMocks.noopLogout
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
            credentialStore: NotesFlowTestMocks.credentialStore(),
            performLogout: NotesFlowTestMocks.noopLogout
        )

        let viewModel = dependencies.makeCreateNoteViewModel()

        XCTAssertTrue(viewModel is DefaultCreateNoteViewModel)
    }

    func testNotesFlowDependenciesStoresInjectedNoteSyncService() {
        let noteSync = ControllableNoteSyncService()
        let dependencies = NotesFlowDependencies(
            authRepository: MockAuthRepository(),
            vaultSession: MockVaultSession(),
            navigator: MockNavigating(),
            noteRepository: MockNoteRepository(),
            credentialStore: NotesFlowTestMocks.credentialStore(),
            noteSync: noteSync,
            performLogout: NotesFlowTestMocks.noopLogout
        )

        let storedSync = dependencies.noteSync as? ControllableNoteSyncService
        XCTAssertTrue(storedSync === noteSync)
    }

    func testNotesFlowDependenciesPassesNoteSyncOutcomeStreamToListViewModel() async {
        let noteID = UUID()
        let noteSync = ControllableNoteSyncService()
        let noteRepository = MockNoteRepository(
            notes: [NoteSummary(noteID: noteID, title: "Pending note", updatedAt: 100, syncState: .pendingSync)]
        )
        let dependencies = NotesFlowDependencies(
            authRepository: MockAuthRepository(),
            vaultSession: MockVaultSession(),
            navigator: MockNavigating(),
            noteRepository: noteRepository,
            credentialStore: NotesFlowTestMocks.credentialStore(),
            noteSync: noteSync,
            performLogout: NotesFlowTestMocks.noopLogout
        )

        let viewModel = dependencies.makeNoteListViewModel()
        await viewModel.refresh()
        XCTAssertEqual(viewModel.notes[0].syncState, .pendingSync)

        await noteRepository.setNotes([
            NoteSummary(noteID: noteID, title: "Pending note", updatedAt: 200, syncState: .synced),
        ])
        await noteSync.emit(
            .uploaded(noteID: noteID, syncState: .synced, updatedAt: 200, etag: #"W/"synced""#)
        )
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(viewModel.notes[0].syncState, .synced)
        XCTAssertEqual(viewModel.notes[0].updatedAt, 200)
    }

    func testNotesFlowDependenciesPassesNoteSyncOutcomeStreamToDetailViewModel() async throws {
        let noteID = UUID()
        let udk = SymmetricKey(size: .bits256)
        let noteData = try NoteViewModelTestSupport.makeStoredNote(
            noteID: noteID,
            title: "Title",
            body: "Body",
            udk: udk,
            syncState: .synced
        )
        let noteSync = ControllableNoteSyncService()
        let noteRepository = StoredNoteMockRepository(notes: [noteID: noteData])
        let dependencies = NotesFlowDependencies(
            authRepository: MockAuthRepository(),
            vaultSession: StoredNoteMockVaultSession(udk: udk),
            navigator: MockNavigating(),
            noteRepository: noteRepository,
            credentialStore: NotesFlowTestMocks.credentialStore(),
            noteSync: noteSync,
            performLogout: NotesFlowTestMocks.noopLogout
        )

        let viewModel = dependencies.makeNoteDetailViewModel(noteID: noteID)
        await viewModel.load()
        viewModel.body = "Changed body"
        await viewModel.save()
        XCTAssertEqual(viewModel.syncState, .pendingSync)

        await noteSync.emit(
            .uploaded(noteID: noteID, syncState: .synced, updatedAt: 1_800_000_200, etag: #"W/"synced""#)
        )
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(viewModel.syncState, .synced)
    }

    func testNotesFlowDependenciesPassesNoteSyncSchedulerToCreateViewModel() async throws {
        let noteSync = RecordingNoteSyncService()
        let udk = SymmetricKey(size: .bits256)
        let noteRepository = StoredNoteMockRepository()
        let dependencies = NotesFlowDependencies(
            authRepository: MockAuthRepository(),
            vaultSession: StoredNoteMockVaultSession(udk: udk),
            navigator: MockNavigating(),
            noteRepository: noteRepository,
            credentialStore: NotesFlowTestMocks.credentialStore(),
            noteSync: noteSync,
            performLogout: NotesFlowTestMocks.noopLogout
        )

        let viewModel = dependencies.makeCreateNoteViewModel()
        viewModel.title = "New note"
        viewModel.body = "Body"
        await viewModel.save()
        await Task.yield()

        let scheduleFlushCallCount = await noteSync.scheduleFlushCallCount
        XCTAssertEqual(scheduleFlushCallCount, 1)
    }

    func testNotesFlowDependenciesDoesNotReceiveNotesIndexStore() {
        let dependencies = NotesFlowDependencies(
            authRepository: MockAuthRepository(),
            vaultSession: MockVaultSession(),
            navigator: MockNavigating(),
            noteRepository: MockNoteRepository(),
            credentialStore: NotesFlowTestMocks.credentialStore(),
            performLogout: NotesFlowTestMocks.noopLogout
        )

        let propertyNames = Mirror(reflecting: dependencies).children.compactMap(\.label)

        XCTAssertTrue(propertyNames.contains("noteRepository"))
        XCTAssertFalse(propertyNames.contains("notesIndexStore"))
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
    private var notes: [NoteSummary]

    init(notes: [NoteSummary] = []) {
        self.notes = notes
    }

    func setNotes(_ notes: [NoteSummary]) {
        self.notes = notes
    }

    func listNotes() async throws -> [NoteSummary] { notes }
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
