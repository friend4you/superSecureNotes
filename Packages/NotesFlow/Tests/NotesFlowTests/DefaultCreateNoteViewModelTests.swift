import CryptoKit
import NavigationProtocol
import NoteRepositoryProtocol
import NotesFlow
import SecureCrypto
import VaultSessionProtocol
import XCTest

@MainActor
private final class MockNavigating: Navigating {
    private(set) var popCount = 0

    func setRoot<R: Route>(_ route: R) {}
    func push<R: Route>(_ route: R) {}
    func present<R: Route>(_ route: R, style: RoutePresentation) {}
    func pop() {
        popCount += 1
    }
    func popToRoot() {}
    func dismissPresentation() {}
}

@MainActor
final class DefaultCreateNoteViewModelTests: XCTestCase {
    func testCanSaveRequiresNonEmptyTitle() {
        let viewModel = makeViewModel()
        viewModel.body = "Some body"

        XCTAssertFalse(viewModel.canSave)

        viewModel.title = "   "
        XCTAssertFalse(viewModel.canSave)

        viewModel.title = "My note"
        XCTAssertTrue(viewModel.canSave)
    }

    func testCanSaveRequiresChangesFromInitialEmptyState() {
        let viewModel = makeViewModel()

        XCTAssertFalse(viewModel.canSave)

        viewModel.title = "Title only"
        XCTAssertTrue(viewModel.canSave)
    }

    func testCanSaveWithTitleAndBody() {
        let viewModel = makeViewModel()
        viewModel.title = "Title"
        viewModel.body = "Body"

        XCTAssertTrue(viewModel.canSave)
    }

    func testCanSaveWithTitleAndAttachment() {
        let viewModel = makeViewModel()
        viewModel.title = "Title"
        viewModel.addAttachment(sampleAttachment(filename: "photo.png"))

        XCTAssertTrue(viewModel.canSave)
    }

    func testAddAttachmentPublishesAttachmentItems() {
        let viewModel = makeViewModel()

        viewModel.addAttachment(sampleAttachment(id: "1", filename: "photo.png", mime: "image/png"))
        viewModel.addAttachment(sampleAttachment(id: "2", filename: "notes.pdf", mime: "application/pdf"))

        XCTAssertEqual(viewModel.attachmentItems.map(\.id), ["1", "2"])
        XCTAssertEqual(viewModel.attachmentItems.map(\.filename), ["photo.png", "notes.pdf"])
        XCTAssertEqual(viewModel.attachmentItems.map(\.mime), ["image/png", "application/pdf"])
    }

    func testRemoveAttachmentRemovesByID() {
        let viewModel = makeViewModel()
        viewModel.addAttachment(sampleAttachment(id: "keep", filename: "keep.txt"))
        viewModel.addAttachment(sampleAttachment(id: "remove", filename: "remove.txt"))

        viewModel.removeAttachment(id: "remove")

        XCTAssertEqual(viewModel.attachmentItems.map(\.filename), ["keep.txt"])
    }

    func testAttachmentDataReturnsBytesForValidID() {
        let viewModel = makeViewModel()
        let attachment = sampleAttachment(id: "data-id", filename: "file.bin", data: Data([0xAB, 0xCD]))
        viewModel.addAttachment(attachment)

        XCTAssertEqual(viewModel.attachmentData(for: "data-id"), Data([0xAB, 0xCD]))
        XCTAssertNil(viewModel.attachmentData(for: "missing"))
    }

    func testSaveWritesStoredNoteWithPendingSyncAndPops() async throws {
        let udk = SymmetricKey(size: .bits256)
        let noteRepository = StoredNoteMockRepository()
        let navigator = MockNavigating()
        let viewModel = makeViewModel(
            noteRepository: noteRepository,
            vaultSession: StoredNoteMockVaultSession(udk: udk),
            navigator: navigator
        )
        viewModel.title = "New note"
        viewModel.body = "New body"
        viewModel.addAttachment(sampleAttachment(filename: "image.png"))

        await viewModel.save()

        let writtenNotes = await noteRepository.writtenNotes
        XCTAssertEqual(writtenNotes.count, 1)
        XCTAssertEqual(navigator.popCount, 1)
        XCTAssertNil(viewModel.errorMessage)

        let storedNote = writtenNotes[0]
        XCTAssertEqual(storedNote.syncState, .pendingSync)
        XCTAssertEqual(storedNote.metadata.title, "New note")
        let fek = try unwrapFEK(storedNote.wrappedFEK, with: udk)
        let payload = try decryptPayload(storedNote.encryptedPayload, with: fek)
        XCTAssertEqual(String(data: payload.body, encoding: .utf8), "New body")
        XCTAssertEqual(payload.attachments.map(\.filename), ["image.png"])
    }

    func testSaveDoesNothingWhenCannotSave() async {
        let noteRepository = StoredNoteMockRepository()
        let navigator = MockNavigating()
        let noteSync = RecordingNoteSyncService()
        let viewModel = makeViewModel(
            noteRepository: noteRepository,
            navigator: navigator,
            noteSync: noteSync
        )

        await viewModel.save()

        let writtenNotes = await noteRepository.writtenNotes
        XCTAssertTrue(writtenNotes.isEmpty)
        XCTAssertEqual(navigator.popCount, 0)
        let scheduleFlushCallCount = await noteSync.scheduleFlushCallCount
        XCTAssertEqual(scheduleFlushCallCount, 0)
    }

    func testSaveCallsScheduleFlushAfterSuccessfulWrite() async throws {
        let udk = SymmetricKey(size: .bits256)
        let noteRepository = StoredNoteMockRepository()
        let noteSync = RecordingNoteSyncService()
        let viewModel = makeViewModel(
            noteRepository: noteRepository,
            vaultSession: StoredNoteMockVaultSession(udk: udk),
            noteSync: noteSync
        )
        viewModel.title = "Scheduled sync"
        viewModel.body = "Body"

        await viewModel.save()
        await Task.yield()

        let scheduleFlushCallCount = await noteSync.scheduleFlushCallCount
        XCTAssertEqual(scheduleFlushCallCount, 1)
    }

    @MainActor
    private func makeViewModel(
        noteRepository: StoredNoteMockRepository = StoredNoteMockRepository(),
        vaultSession: StoredNoteMockVaultSession = StoredNoteMockVaultSession(),
        navigator: MockNavigating? = nil,
        noteSync: RecordingNoteSyncService = RecordingNoteSyncService()
    ) -> DefaultCreateNoteViewModel {
        DefaultCreateNoteViewModel(
            noteRepository: noteRepository,
            vaultSession: vaultSession,
            navigator: navigator ?? MockNavigating(),
            noteSync: noteSync
        )
    }

    private func sampleAttachment(
        id: String = UUID().uuidString,
        filename: String,
        mime: String = "application/octet-stream",
        data: Data = Data([0x01])
    ) -> NotePayload.Attachment {
        NotePayload.Attachment(
            id: id,
            filename: filename,
            mime: mime,
            data: data
        )
    }
}
