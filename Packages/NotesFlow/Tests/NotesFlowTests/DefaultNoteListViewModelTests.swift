import AuthFlowRoutes
import AuthRepositoryProtocol
import CredentialStoreProtocol
import CryptoKit
import NavigationProtocol
import NoteRepositoryProtocol
import NotesFlow
import SecureCrypto
import NotesFlowRoutes
import ShareNoteRoutes
import VaultSessionProtocol
import XCTest

@MainActor
private final class MockNavigating: Navigating {
    private(set) var pushedRoutes: [AnyHashable] = []
    private(set) var presentedRoutes: [(route: AnyHashable, style: RoutePresentation)] = []

    func setRoot<R: Route>(_ route: R) {}
    func push<R: Route>(_ route: R) {
        pushedRoutes.append(AnyHashable(route))
    }
    func present<R: Route>(_ route: R, style: RoutePresentation) {
        presentedRoutes.append((AnyHashable(route), style))
    }
    func pop() {}
    func popToRoot() {}
    func dismissPresentation() {}
}

@MainActor
final class DefaultNoteListViewModelTests: XCTestCase {
    func testRefreshLoadsNotesSortedByUpdatedAtDescending() async {
        let olderID = UUID()
        let newerID = UUID()
        let noteRepository = MockNoteRepository(
            notes: [
                NoteSummary(noteID: olderID, title: "Older", updatedAt: 100),
                NoteSummary(noteID: newerID, title: "Newer", updatedAt: 200),
            ]
        )
        let viewModel = makeViewModel(noteRepository: noteRepository)

        await viewModel.refresh()

        let listNotesCallCount = await noteRepository.listNotesCallCount
        XCTAssertEqual(viewModel.notes.map(\.noteID), [newerID, olderID])
        XCTAssertEqual(listNotesCallCount, 1)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testOpenDetailPushesDetailRoute() {
        let noteID = UUID()
        let navigator = MockNavigating()
        let viewModel = makeViewModel(navigator: navigator)

        viewModel.openDetail(noteID: noteID)

        XCTAssertEqual(navigator.pushedRoutes.count, 1)
        XCTAssertEqual(navigator.pushedRoutes.first?.base as? NotesRoute, .detail(noteID: noteID))
    }

    func testCreateNotePushesCreateRoute() {
        let navigator = MockNavigating()
        let viewModel = makeViewModel(navigator: navigator)

        viewModel.createNote()

        XCTAssertEqual(navigator.pushedRoutes.count, 1)
        XCTAssertEqual(navigator.pushedRoutes.first?.base as? NotesRoute, .create)
    }

    func testOpenSettingsPushesSettingsRoute() {
        let navigator = MockNavigating()
        let viewModel = makeViewModel(navigator: navigator)

        viewModel.openSettings()

        XCTAssertEqual(navigator.pushedRoutes.count, 1)
        XCTAssertEqual(navigator.pushedRoutes.first?.base as? AuthRoute, .settings)
    }

    func testSharePresentsShareSheet() {
        let noteID = UUID()
        let navigator = MockNavigating()
        let viewModel = makeViewModel(navigator: navigator)

        viewModel.share(noteID: noteID)

        XCTAssertEqual(navigator.presentedRoutes.count, 1)
        XCTAssertEqual(navigator.presentedRoutes.first?.style, .sheet)
        XCTAssertEqual(
            navigator.presentedRoutes.first?.route.base as? ShareNoteRoute,
            .share(noteID: noteID)
        )
    }

    func testDeleteNoteCallsRepositoryAndRefreshesList() async {
        let remainingID = UUID()
        let deletedID = UUID()
        let noteRepository = MockNoteRepository(
            notes: [
                NoteSummary(noteID: deletedID, title: "Delete me", updatedAt: 100),
                NoteSummary(noteID: remainingID, title: "Keep", updatedAt: 200),
            ]
        )
        let viewModel = makeViewModel(noteRepository: noteRepository)

        await viewModel.deleteNote(noteID: deletedID)

        let deletedNoteIDs = await noteRepository.deletedNoteIDs
        let listNotesCallCount = await noteRepository.listNotesCallCount
        XCTAssertEqual(deletedNoteIDs, [deletedID])
        XCTAssertEqual(listNotesCallCount, 1)
        XCTAssertEqual(viewModel.notes.map(\.noteID), [remainingID])
    }

    func testLogoutClearsAuthAndVaultSession() async throws {
        let authRepository = MockAuthRepository()
        let vaultSession = MockVaultSession()
        let credentialStore = NotesFlowTestMocks.credentialStore()
        try credentialStore.saveSetup(
            email: "user@example.com",
            refreshToken: "refresh-token",
            vaultHeader: Data([0x01])
        )
        _ = try await authRepository.login(
            LoginCredentials(email: "user@example.com", password: "secret")
        )
        await vaultSession.establish(
            VaultSessionKeys(
                udk: .init(size: .bits256),
                identityPrivateKey: Data(repeating: 0x01, count: 32)
            )
        )

        let viewModel = makeViewModel(
            authRepository: authRepository,
            vaultSession: vaultSession,
            credentialStore: credentialStore,
            performLogout: {
                try? await authRepository.logout()
                try? credentialStore.clearAll()
                await vaultSession.clear()
            }
        )
        await viewModel.logout()

        let currentSession = await authRepository.currentSession
        let isActive = await vaultSession.isActive
        XCTAssertNil(currentSession)
        XCTAssertFalse(isActive)
        XCTAssertFalse(credentialStore.hasLocalSetup)
    }

    @MainActor
    private func makeViewModel(
        authRepository: MockAuthRepository = MockAuthRepository(),
        vaultSession: MockVaultSession = MockVaultSession(),
        noteRepository: MockNoteRepository = MockNoteRepository(),
        navigator: MockNavigating? = nil,
        credentialStore: MockCredentialStore = NotesFlowTestMocks.credentialStore(),
        performLogout: (() async -> Void)? = nil
    ) -> DefaultNoteListViewModel {
        DefaultNoteListViewModel(
            authRepository: authRepository,
            vaultSession: vaultSession,
            noteRepository: noteRepository,
            navigator: navigator ?? MockNavigating(),
            credentialStore: credentialStore,
            performLogout: performLogout ?? NotesFlowTestMocks.noopLogout
        )
    }
}

private actor MockNoteRepository: NoteRepository {
    private var notes: [NoteSummary]
    private(set) var listNotesCallCount = 0
    private(set) var deletedNoteIDs: [UUID] = []

    init(notes: [NoteSummary] = []) {
        self.notes = notes
    }

    func listNotes() async throws -> [NoteSummary] {
        listNotesCallCount += 1
        return notes
    }

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

    func deleteNote(noteID: UUID) async throws {
        deletedNoteIDs.append(noteID)
        notes.removeAll { $0.noteID == noteID }
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

    func restoreSession(refreshToken: String) async throws -> AuthSession {
        session = AuthSession(
            accessToken: "access",
            refreshToken: refreshToken,
            expiresAt: .distantFuture
        )
        return session!
    }

    func clearSession() async {
        session = nil
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
