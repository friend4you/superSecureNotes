import AuthRepositoryProtocol
import CryptoKit
import NavigationProtocol
import NoteRepositoryProtocol
import NotesFlow
import SecureCrypto
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
final class NoteListViewTests: XCTestCase {
    func testNoteListViewAcceptsViewModel() {
        let viewModel = makeViewModel()

        _ = NoteListView(viewModel: viewModel)
    }

    func testViewModelNotesAreAvailableForListDisplay() async {
        let noteID = UUID()
        let noteRepository = MockNoteRepository(
            notes: [NoteSummary(noteID: noteID, title: "Meeting notes", updatedAt: 100, syncState: .synced)]
        )
        let viewModel = makeViewModel(noteRepository: noteRepository)

        await viewModel.refresh()

        XCTAssertEqual(viewModel.notes.map(\.title), ["Meeting notes"])
    }

    func testPullToRefreshCallsViewModelRefresh() async {
        let noteRepository = MockNoteRepository()
        let viewModel = makeViewModel(noteRepository: noteRepository)

        await viewModel.refresh()

        let listNotesCallCount = await noteRepository.listNotesCallCount
        XCTAssertEqual(listNotesCallCount, 1)
    }

    func testShareFromContextMenuUsesViewModelShare() {
        let noteID = UUID()
        let navigator = MockNavigating()
        let viewModel = makeViewModel(navigator: navigator)

        viewModel.share(noteID: noteID)

        XCTAssertEqual(navigator.presentedRoutes.count, 1)
    }

    func testDeleteConfirmationUsesViewModelDeleteNote() async {
        let noteID = UUID()
        let noteRepository = MockNoteRepository(
            notes: [NoteSummary(noteID: noteID, title: "Delete me", updatedAt: 100, syncState: .synced)]
        )
        let viewModel = makeViewModel(noteRepository: noteRepository)

        await viewModel.deleteNote(noteID: noteID)

        let deletedNoteIDs = await noteRepository.deletedNoteIDs
        XCTAssertEqual(deletedNoteIDs, [noteID])
    }

    func testNoteListViewSourceRendersTitlesFromViewModel() throws {
        let source = try Self.noteListViewSource()

        XCTAssertTrue(source.contains("ForEach(viewModel.notes"))
        XCTAssertTrue(source.contains("Text(note.title)"))
    }

    func testNoteListViewSourceUsesTabViewForSegments() throws {
        let source = try Self.noteListViewSource()

        XCTAssertTrue(source.contains("TabView(selection: $viewModel.selectedSegment)"))
        XCTAssertTrue(source.contains(".tabItem"))
        XCTAssertTrue(source.contains("notes.list.segment.myNotes"))
        XCTAssertTrue(source.contains("notes.list.segment.shared"))
        XCTAssertFalse(source.contains(".pickerStyle(.segmented)"))
    }

    func testNoteListViewSourceUsesRefreshable() throws {
        let source = try Self.noteListViewSource()

        XCTAssertTrue(source.contains(".refreshable"))
        XCTAssertTrue(source.contains("await viewModel.refresh()"))
    }

    func testNoteListViewSourceContextMenuOffersShareAndDelete() throws {
        let source = try Self.noteListViewSource()

        XCTAssertTrue(source.contains(".contextMenu"))
        XCTAssertTrue(source.contains("viewModel.share(noteID: note.noteID)"))
        XCTAssertTrue(source.contains("pendingDeleteNoteID = note.noteID"))
    }

    func testNoteListViewSourceShowsDeleteConfirmation() throws {
        let source = try Self.noteListViewSource()

        XCTAssertTrue(source.contains(".alert("))
        XCTAssertTrue(source.contains("notes.delete.confirmation"))
        XCTAssertTrue(source.contains("await viewModel.deleteNote(noteID: noteID)"))
    }

    func testNoteListViewSourceSharedContextMenuOffersDelete() throws {
        let source = try Self.noteListViewSource()

        XCTAssertTrue(source.contains("pendingDeleteSharedNoteID = note.noteID"))
        XCTAssertTrue(source.contains("await viewModel.deleteSharedNote(noteID: noteID)"))
        XCTAssertTrue(source.contains("notes.shared.delete.confirmation"))
    }

    func testNoteListViewSourceOwnedRowUsesTrailingIconOnlySync() throws {
        let source = try Self.noteListViewSource()

        XCTAssertTrue(source.contains("NoteSyncStatusLabel(syncState: note.syncState, displayStyle: .iconOnly)"))
        XCTAssertTrue(source.contains("HStack"))
        XCTAssertTrue(source.contains("Text(note.title)"))
        XCTAssertTrue(source.contains("Spacer()"))
    }

    func testNoteListViewSourceSharedRowHasNoSync() throws {
        let source = try Self.noteListViewSource()

        let sharedSection = source.components(separatedBy: "viewModel.sharedNotes").last ?? ""
        XCTAssertFalse(sharedSection.contains("NoteSyncStatusLabel"))
    }

    func testNoteListViewSourceToolbarUsesGearshapeLeadingAndPlusTrailing() throws {
        let source = try Self.noteListViewSource()

        XCTAssertTrue(source.contains("gearshape"))
        XCTAssertTrue(source.contains("Image(systemName: \"plus\")"))
        XCTAssertTrue(source.contains("placement: .topBarLeading"))
        XCTAssertTrue(source.contains("placement: .primaryAction"))
    }

    func testNoteListViewSourceHasNoLogoutButton() throws {
        let source = try Self.noteListViewSource()
        let bodySection = source.components(separatedBy: "public var body: some View").last ?? source

        XCTAssertFalse(bodySection.contains("notes.list.logout"))
        XCTAssertFalse(bodySection.contains("viewModel.logout()"))
    }

    func testNoteListViewSourceSettingsButtonOpensSettings() throws {
        let source = try Self.noteListViewSource()

        XCTAssertTrue(source.contains("notes.list.settings"))
        XCTAssertTrue(source.contains("viewModel.openSettings()"))
    }

    func testNoteListViewSourceDoesNotShowPlaceholderText() throws {
        let source = try Self.noteListViewSource()

        XCTAssertFalse(source.contains("Text(\"Note list\")"))
    }

    func testNoteListViewSourceUsesLocalizedNavigationTitle() throws {
        let source = try Self.noteListViewSource()

        XCTAssertTrue(source.contains("notes.list.title"))
        XCTAssertTrue(source.contains("NotesFlowUILocalization.localized"))
    }

    func testNoteListViewSourceShowsSyncStatusFromSyncState() throws {
        let source = try Self.noteListViewSource()

        XCTAssertTrue(source.contains("note.syncState"))
        XCTAssertTrue(source.contains("NoteSyncStatusLabel(syncState: note.syncState, displayStyle: .iconOnly)"))
    }

    func testNoteListViewSourceReloadsSummariesOnAppear() throws {
        let source = try Self.noteListViewSource()

        XCTAssertTrue(source.contains(".onAppear"))
        XCTAssertTrue(source.contains("viewModel.reloadSummaries()"))
    }

    func testRefreshInvokesSyncFlushBeforeReloadingNotes() async {
        let noteSync = MockNoteSyncService()
        let noteRepository = MockNoteRepository(
            notes: [NoteSummary(noteID: UUID(), title: "Note", updatedAt: 100, syncState: .synced)]
        )
        let viewModel = makeViewModel(noteRepository: noteRepository, noteSync: noteSync)

        await viewModel.refresh()

        let flushCallCount = await noteSync.flushCallCount
        let listNotesCallCount = await noteRepository.listNotesCallCount
        XCTAssertEqual(flushCallCount, 1)
        XCTAssertEqual(listNotesCallCount, 1)
    }

    @MainActor
    private func makeViewModel(
        noteRepository: MockNoteRepository = MockNoteRepository(),
        navigator: MockNavigating? = nil,
        noteSync: MockNoteSyncService = MockNoteSyncService()
    ) -> DefaultNoteListViewModel {
        DefaultNoteListViewModel(
            authRepository: MockAuthRepository(),
            vaultSession: MockVaultSession(),
            noteRepository: noteRepository,
            navigator: navigator ?? MockNavigating(),
            credentialStore: NotesFlowTestMocks.credentialStore(),
            performLogout: NotesFlowTestMocks.noopLogout,
            noteSync: noteSync
        )
    }

    private static func noteListViewSource() throws -> String {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = packageRoot
            .appendingPathComponent("Sources/NotesFlow/NoteListView.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
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

    func shareNote(noteID: UUID, recipientEmail: String, wrappedFEK: Data) async throws {
        _ = noteID
        _ = recipientEmail
        _ = wrappedFEK
        throw NoteRepositoryError.notSupported
    }

    func listSharedNotes() async throws -> [SharedNoteSummary] {
        []
    }

    func readSharedNote(noteID: UUID) async throws -> SharedNote {
        _ = noteID
        throw NoteRepositoryError.notSupported
    }

    func deleteSharedNote(noteID: UUID) async throws {
        _ = noteID
        throw NoteRepositoryError.notSupported
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

private actor MockNoteSyncService: NoteSyncing {
    private(set) var flushCallCount = 0

    nonisolated let syncOutcomes: AsyncStream<NoteSyncOutcome> = AsyncStream { $0.finish() }

    func flushPending() async {
        flushCallCount += 1
    }

    func pullVaultHeaderIfLocalMissing() async throws -> Data? {
        nil
    }

    func pullRemoteNotesCatalog() async throws {}

    func pullCatalogIfLocalVaultMissing() async throws -> Data? {
        nil
    }

    func uploadVaultHeaderOrThrow(_ header: Data) async throws {}

    nonisolated func scheduleFlush() {
        Task { await flushPending() }
    }

    nonisolated func scheduleVaultHeaderUpload(_ header: Data) {}
}
