import CryptoKit
import NavigationProtocol
import NoteRepositoryProtocol
import NotesFlow
import NotesFlowRoutes
import SecureCrypto
import ShareNoteRoutes
import VaultSessionProtocol
import XCTest

@MainActor
private final class MockNavigating: Navigating {
    private(set) var pushedRoutes: [AnyHashable] = []
    private(set) var presentedRoutes: [(route: AnyHashable, style: RoutePresentation)] = []
    private(set) var popCount = 0

    func setRoot<R: Route>(_ route: R) {}
    func push<R: Route>(_ route: R) {
        pushedRoutes.append(AnyHashable(route))
    }
    func present<R: Route>(_ route: R, style: RoutePresentation) {
        presentedRoutes.append((AnyHashable(route), style))
    }
    func pop() {
        popCount += 1
    }
    func popToRoot() {}
    func dismissPresentation() {}
}

@MainActor
final class DefaultNoteDetailViewModelTests: XCTestCase {
    func testLoadDecryptsNoteContent() async throws {
        let noteID = UUID()
        let udk = SymmetricKey(size: .bits256)
        let noteData = try NoteViewModelTestSupport.makeStoredNote(
            noteID: noteID,
            title: "Shopping list",
            body: "Milk and eggs",
            udk: udk,
            attachments: [
                NotePayload.Attachment(
                    id: "attachment-1",
                    filename: "receipt.pdf",
                    mime: "application/pdf",
                    data: Data([0x01, 0x02])
                ),
            ]
        )
        let noteRepository = StoredNoteMockRepository(notes: [noteID: noteData])
        let viewModel = makeViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            vaultSession: StoredNoteMockVaultSession(udk: udk)
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.title, "Shopping list")
        XCTAssertEqual(viewModel.body, "Milk and eggs")
        XCTAssertEqual(viewModel.attachmentItems.map(\.filename), ["receipt.pdf"])
        XCTAssertEqual(viewModel.attachmentItems.map(\.id), ["attachment-1"])
        XCTAssertFalse(viewModel.hasChanges)
        XCTAssertFalse(viewModel.canSave)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLoadExposesSyncStateFromStoredNote() async throws {
        let noteID = UUID()
        let udk = SymmetricKey(size: .bits256)
        let noteData = try NoteViewModelTestSupport.makeStoredNote(
            noteID: noteID,
            title: "Synced note",
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

        XCTAssertEqual(viewModel.syncState, .synced)
    }

    func testSaveUpdatesSyncStateToPendingSync() async throws {
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
        viewModel.body = "Changed body"

        await viewModel.save()

        XCTAssertEqual(viewModel.syncState, .pendingSync)
    }

    func testSaveCallsScheduleFlushAfterSuccessfulWrite() async throws {
        let noteID = UUID()
        let udk = SymmetricKey(size: .bits256)
        let noteData = try NoteViewModelTestSupport.makeStoredNote(
            noteID: noteID,
            title: "Title",
            body: "Body",
            udk: udk,
            syncState: .synced
        )
        let noteSync = RecordingNoteSyncService()
        let viewModel = makeViewModel(
            noteID: noteID,
            noteRepository: StoredNoteMockRepository(notes: [noteID: noteData]),
            vaultSession: StoredNoteMockVaultSession(udk: udk),
            noteSync: noteSync
        )
        await viewModel.load()
        viewModel.body = "Changed body"

        await viewModel.save()
        await Task.yield()

        let scheduleFlushCallCount = await noteSync.scheduleFlushCallCount
        XCTAssertEqual(scheduleFlushCallCount, 1)
    }

    func testUpdatesSyncStateOnSuccessfulSyncOutcome() async throws {
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
        viewModel.body = "Changed body"
        await viewModel.save()
        XCTAssertEqual(viewModel.syncState, .pendingSync)

        await noteSync.emit(
            .uploaded(noteID: noteID, syncState: .synced, updatedAt: 1_800_000_200, etag: #"W/"synced""#)
        )
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(viewModel.syncState, .synced)
    }

    func testAddAttachmentMarksDetailDirty() async throws {
        let noteID = UUID()
        let udk = SymmetricKey(size: .bits256)
        let noteData = try NoteViewModelTestSupport.makeStoredNote(
            noteID: noteID,
            title: "Title",
            body: "Body",
            udk: udk
        )
        let viewModel = makeViewModel(
            noteID: noteID,
            noteRepository: StoredNoteMockRepository(notes: [noteID: noteData]),
            vaultSession: StoredNoteMockVaultSession(udk: udk)
        )
        await viewModel.load()

        viewModel.addAttachment(
            NotePayload.Attachment(
                id: "new-attachment",
                filename: "new.txt",
                mime: "text/plain",
                data: Data("hello".utf8)
            )
        )

        XCTAssertEqual(viewModel.attachmentItems.map(\.id), ["new-attachment"])
        XCTAssertTrue(viewModel.hasChanges)
        XCTAssertTrue(viewModel.canSave)
    }

    func testRemoveAttachmentMarksDetailDirty() async throws {
        let noteID = UUID()
        let udk = SymmetricKey(size: .bits256)
        let noteData = try NoteViewModelTestSupport.makeStoredNote(
            noteID: noteID,
            title: "Title",
            body: "Body",
            udk: udk,
            attachments: [
                NotePayload.Attachment(
                    id: "attachment-1",
                    filename: "receipt.pdf",
                    mime: "application/pdf",
                    data: Data([0x01])
                ),
            ]
        )
        let viewModel = makeViewModel(
            noteID: noteID,
            noteRepository: StoredNoteMockRepository(notes: [noteID: noteData]),
            vaultSession: StoredNoteMockVaultSession(udk: udk)
        )
        await viewModel.load()

        viewModel.removeAttachment(id: "attachment-1")

        XCTAssertTrue(viewModel.attachmentItems.isEmpty)
        XCTAssertTrue(viewModel.hasChanges)
        XCTAssertTrue(viewModel.canSave)
    }

    func testSavePersistsAttachmentChanges() async throws {
        let noteID = UUID()
        let udk = SymmetricKey(size: .bits256)
        let noteData = try NoteViewModelTestSupport.makeStoredNote(
            noteID: noteID,
            title: "Title",
            body: "Body",
            udk: udk
        )
        let noteRepository = StoredNoteMockRepository(notes: [noteID: noteData])
        let viewModel = makeViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            vaultSession: StoredNoteMockVaultSession(udk: udk)
        )
        await viewModel.load()
        viewModel.addAttachment(
            NotePayload.Attachment(
                id: "saved-attachment",
                filename: "saved.txt",
                mime: "text/plain",
                data: Data("saved".utf8)
            )
        )

        await viewModel.save()

        let savedNote = try await noteRepository.storedNote(noteID: noteID)
        let fek = try unwrapFEK(savedNote.wrappedFEK, with: udk)
        let payload = try decryptPayload(savedNote.encryptedPayload, with: fek)
        XCTAssertEqual(savedNote.syncState, .pendingSync)
        XCTAssertEqual(payload.attachments.map(\.filename), ["saved.txt"])
        XCTAssertFalse(viewModel.hasChanges)
    }

    func testAttachmentDataReturnsBytesForValidID() async throws {
        let noteID = UUID()
        let udk = SymmetricKey(size: .bits256)
        let noteData = try NoteViewModelTestSupport.makeStoredNote(
            noteID: noteID,
            title: "Title",
            body: "Body",
            udk: udk,
            attachments: [
                NotePayload.Attachment(
                    id: "attachment-1",
                    filename: "receipt.pdf",
                    mime: "application/pdf",
                    data: Data([0x01, 0x02])
                ),
            ]
        )
        let viewModel = makeViewModel(
            noteID: noteID,
            noteRepository: StoredNoteMockRepository(notes: [noteID: noteData]),
            vaultSession: StoredNoteMockVaultSession(udk: udk)
        )
        await viewModel.load()

        XCTAssertEqual(viewModel.attachmentData(for: "attachment-1"), Data([0x01, 0x02]))
        XCTAssertNil(viewModel.attachmentData(for: "missing"))
    }

    func testLoadOnlyRunsOncePerViewModel() async throws {
        let noteID = UUID()
        let udk = SymmetricKey(size: .bits256)
        let noteData = try NoteViewModelTestSupport.makeStoredNote(
            noteID: noteID,
            title: "Title",
            body: "Body",
            udk: udk
        )
        let noteRepository = StoredNoteMockRepository(notes: [noteID: noteData])
        let viewModel = makeViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            vaultSession: StoredNoteMockVaultSession(udk: udk)
        )

        await viewModel.load()
        viewModel.addAttachment(
            NotePayload.Attachment(
                id: "new-attachment",
                filename: "new.txt",
                mime: "text/plain",
                data: Data("hello".utf8)
            )
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.attachmentItems.map(\.id), ["new-attachment"])
    }

    func testSaveWritesEncryptedBlob() async throws {
        let noteID = UUID()
        let udk = SymmetricKey(size: .bits256)
        let noteData = try NoteViewModelTestSupport.makeStoredNote(
            noteID: noteID,
            title: "Original title",
            body: "Original body",
            udk: udk
        )
        let noteRepository = StoredNoteMockRepository(notes: [noteID: noteData])
        let viewModel = makeViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            vaultSession: StoredNoteMockVaultSession(udk: udk)
        )
        await viewModel.load()
        viewModel.title = "Updated title"
        viewModel.body = "Updated body"

        await viewModel.save()

        let savedNote = try await noteRepository.storedNote(noteID: noteID)
        let fek = try unwrapFEK(savedNote.wrappedFEK, with: udk)
        let payload = try decryptPayload(savedNote.encryptedPayload, with: fek)
        XCTAssertEqual(savedNote.syncState, .pendingSync)
        XCTAssertEqual(savedNote.metadata.title, "Updated title")
        XCTAssertEqual(String(data: payload.body, encoding: .utf8), "Updated body")
        XCTAssertTrue(viewModel.canSave == false)
        XCTAssertFalse(viewModel.hasChanges)
    }

    func testCanSaveRequiresChangesAndNonEmptyTitle() async throws {
        let noteID = UUID()
        let udk = SymmetricKey(size: .bits256)
        let noteData = try NoteViewModelTestSupport.makeStoredNote(
            noteID: noteID,
            title: "Title",
            body: "Body",
            udk: udk
        )
        let viewModel = makeViewModel(
            noteID: noteID,
            noteRepository: StoredNoteMockRepository(notes: [noteID: noteData]),
            vaultSession: StoredNoteMockVaultSession(udk: udk)
        )
        await viewModel.load()

        XCTAssertFalse(viewModel.canSave)

        viewModel.body = "Changed body"
        XCTAssertTrue(viewModel.canSave)

        viewModel.title = "   "
        XCTAssertFalse(viewModel.canSave)

        viewModel.title = "Valid title"
        XCTAssertTrue(viewModel.canSave)
    }

    func testSharePresentsShareSheet() {
        let noteID = UUID()
        let navigator = MockNavigating()
        let viewModel = makeViewModel(noteID: noteID, navigator: navigator)

        viewModel.share()

        XCTAssertEqual(navigator.presentedRoutes.count, 1)
        XCTAssertEqual(navigator.presentedRoutes.first?.style, .sheet)
        XCTAssertEqual(
            navigator.presentedRoutes.first?.route.base as? ShareNoteRoute,
            .share(noteID: noteID)
        )
    }

    func testDeleteCallsRepositoryAndPops() async {
        let noteID = UUID()
        let noteRepository = StoredNoteMockRepository()
        let navigator = MockNavigating()
        let viewModel = makeViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            navigator: navigator
        )

        await viewModel.delete()

        let deletedNoteIDs = await noteRepository.deletedNoteIDs
        XCTAssertEqual(deletedNoteIDs, [noteID])
        XCTAssertEqual(navigator.popCount, 1)
    }

    @MainActor
    private func makeViewModel(
        noteID: UUID = UUID(),
        noteRepository: StoredNoteMockRepository = StoredNoteMockRepository(),
        vaultSession: StoredNoteMockVaultSession = StoredNoteMockVaultSession(),
        navigator: MockNavigating? = nil,
        noteSync: any NoteSyncing = RecordingNoteSyncService()
    ) -> DefaultNoteDetailViewModel {
        DefaultNoteDetailViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            vaultSession: vaultSession,
            navigator: navigator ?? MockNavigating(),
            noteSync: noteSync
        )
    }
}
