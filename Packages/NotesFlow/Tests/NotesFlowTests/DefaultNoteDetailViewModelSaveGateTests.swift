import CryptoKit
import NavigationProtocol
import NoteRepositoryProtocol
import NotesFlow
import SecureCrypto
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
final class DefaultNoteDetailViewModelSaveGateTests: XCTestCase {
    func testCanSaveFalseWhenPendingSyncEvenIfDirty() async throws {
        let noteID = UUID()
        let udk = SymmetricKey(size: .bits256)
        let noteData = try NoteViewModelTestSupport.makeStoredNote(
            noteID: noteID,
            title: "Title",
            body: "Body",
            udk: udk,
            syncState: .pendingSync
        )
        let viewModel = makeViewModel(
            noteID: noteID,
            noteRepository: StoredNoteMockRepository(notes: [noteID: noteData]),
            vaultSession: StoredNoteMockVaultSession(udk: udk)
        )
        await viewModel.load()
        viewModel.body = "Dirty body"

        XCTAssertTrue(viewModel.hasChanges)
        XCTAssertEqual(viewModel.syncState, .pendingSync)
        XCTAssertFalse(viewModel.canSave)
    }

    func testCanSaveTrueWhenSyncedAndDirty() async throws {
        let noteID = UUID()
        let udk = SymmetricKey(size: .bits256)
        let noteData = try NoteViewModelTestSupport.makeStoredNote(
            noteID: noteID,
            title: "Title",
            body: "Body",
            udk: udk,
            syncState: .synced
        )
        let viewModel = makeViewModel(
            noteID: noteID,
            noteRepository: StoredNoteMockRepository(notes: [noteID: noteData]),
            vaultSession: StoredNoteMockVaultSession(udk: udk)
        )
        await viewModel.load()
        viewModel.body = "Dirty body"

        XCTAssertTrue(viewModel.hasChanges)
        XCTAssertEqual(viewModel.syncState, .synced)
        XCTAssertTrue(viewModel.canSave)
    }

    func testCanSaveBecomesTrueAfterSyncCompletesWhileDirty() async throws {
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
        let viewModel = makeViewModel(
            noteID: noteID,
            noteRepository: StoredNoteMockRepository(notes: [noteID: noteData]),
            vaultSession: StoredNoteMockVaultSession(udk: udk),
            noteSync: noteSync
        )
        await viewModel.load()
        viewModel.body = "First edit"
        await viewModel.save()
        XCTAssertEqual(viewModel.syncState, .pendingSync)
        XCTAssertFalse(viewModel.canSave)

        viewModel.body = "Second edit while pending"
        XCTAssertFalse(viewModel.canSave)

        await noteSync.emit(
            .uploaded(noteID: noteID, syncState: .synced, updatedAt: 1_800_000_200, etag: #"W/"ok""#)
        )
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(viewModel.syncState, .synced)
        XCTAssertTrue(viewModel.hasChanges)
        XCTAssertTrue(viewModel.canSave)
    }

    func testCreateNoteCanSaveDoesNotRequireSyncedState() {
        let viewModel = DefaultCreateNoteViewModel(
            noteRepository: StoredNoteMockRepository(),
            vaultSession: StoredNoteMockVaultSession(),
            navigator: MockNavigating()
        )
        viewModel.title = "Brand new"
        viewModel.body = "Body"

        XCTAssertTrue(viewModel.canSave)
    }

    private func makeViewModel(
        noteID: UUID,
        noteRepository: StoredNoteMockRepository,
        vaultSession: StoredNoteMockVaultSession,
        noteSync: any NoteSyncing = RecordingNoteSyncService()
    ) -> DefaultNoteDetailViewModel {
        DefaultNoteDetailViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            vaultSession: vaultSession,
            navigator: MockNavigating(),
            noteSync: noteSync
        )
    }
}
