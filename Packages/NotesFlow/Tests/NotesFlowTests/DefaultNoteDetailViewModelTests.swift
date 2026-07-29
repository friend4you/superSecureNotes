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
        let noteData = try makeEncryptedNoteFile(
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
        let noteRepository = MockNoteRepository(notes: [noteID: noteData])
        let viewModel = makeViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            vaultSession: MockVaultSession(udk: udk)
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

    func testAddAttachmentMarksDetailDirty() async throws {
        let noteID = UUID()
        let udk = SymmetricKey(size: .bits256)
        let noteData = try makeEncryptedNoteFile(
            noteID: noteID,
            title: "Title",
            body: "Body",
            udk: udk
        )
        let viewModel = makeViewModel(
            noteID: noteID,
            noteRepository: MockNoteRepository(notes: [noteID: noteData]),
            vaultSession: MockVaultSession(udk: udk)
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
        let noteData = try makeEncryptedNoteFile(
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
            noteRepository: MockNoteRepository(notes: [noteID: noteData]),
            vaultSession: MockVaultSession(udk: udk)
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
        let noteData = try makeEncryptedNoteFile(
            noteID: noteID,
            title: "Title",
            body: "Body",
            udk: udk
        )
        let noteRepository = MockNoteRepository(notes: [noteID: noteData])
        let viewModel = makeViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            vaultSession: MockVaultSession(udk: udk)
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

        let savedData = try await noteRepository.noteData(noteID: noteID)
        let sections = try parseNoteFile(savedData)
        let fek = try unwrapFEK(sections.wrappedFEK, with: udk)
        let payload = try decryptPayload(sections.encryptedPayload, with: fek)
        XCTAssertEqual(payload.attachments.map(\.filename), ["saved.txt"])
        XCTAssertFalse(viewModel.hasChanges)
    }

    func testAttachmentDataReturnsBytesForValidID() async throws {
        let noteID = UUID()
        let udk = SymmetricKey(size: .bits256)
        let noteData = try makeEncryptedNoteFile(
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
            noteRepository: MockNoteRepository(notes: [noteID: noteData]),
            vaultSession: MockVaultSession(udk: udk)
        )
        await viewModel.load()

        XCTAssertEqual(viewModel.attachmentData(for: "attachment-1"), Data([0x01, 0x02]))
        XCTAssertNil(viewModel.attachmentData(for: "missing"))
    }

    func testSaveWritesEncryptedBlob() async throws {
        let noteID = UUID()
        let udk = SymmetricKey(size: .bits256)
        let noteData = try makeEncryptedNoteFile(
            noteID: noteID,
            title: "Original title",
            body: "Original body",
            udk: udk
        )
        let noteRepository = MockNoteRepository(notes: [noteID: noteData])
        let viewModel = makeViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            vaultSession: MockVaultSession(udk: udk)
        )
        await viewModel.load()
        viewModel.title = "Updated title"
        viewModel.body = "Updated body"

        await viewModel.save()

        let savedData = try await noteRepository.noteData(noteID: noteID)
        let sections = try parseNoteFile(savedData)
        let fek = try unwrapFEK(sections.wrappedFEK, with: udk)
        let payload = try decryptPayload(sections.encryptedPayload, with: fek)
        XCTAssertEqual(sections.metadata.title, "Updated title")
        XCTAssertEqual(String(data: payload.body, encoding: .utf8), "Updated body")
        XCTAssertTrue(viewModel.canSave == false)
        XCTAssertFalse(viewModel.hasChanges)
    }

    func testCanSaveRequiresChangesAndNonEmptyTitle() async throws {
        let noteID = UUID()
        let udk = SymmetricKey(size: .bits256)
        let noteData = try makeEncryptedNoteFile(
            noteID: noteID,
            title: "Title",
            body: "Body",
            udk: udk
        )
        let viewModel = makeViewModel(
            noteID: noteID,
            noteRepository: MockNoteRepository(notes: [noteID: noteData]),
            vaultSession: MockVaultSession(udk: udk)
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
        let noteRepository = MockNoteRepository()
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
        noteRepository: MockNoteRepository = MockNoteRepository(),
        vaultSession: MockVaultSession = MockVaultSession(),
        navigator: MockNavigating? = nil
    ) -> DefaultNoteDetailViewModel {
        DefaultNoteDetailViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            vaultSession: vaultSession,
            navigator: navigator ?? MockNavigating()
        )
    }

    private func makeEncryptedNoteFile(
        noteID: UUID,
        title: String,
        body: String,
        udk: SymmetricKey,
        attachments: [NotePayload.Attachment] = [],
        createdAt: UInt64 = 1_700_000_000,
        updatedAt: UInt64 = 1_700_000_100
    ) throws -> Data {
        let fek = generateSymmetricKey()
        let payload = NotePayload(body: Data(body.utf8), attachments: attachments)
        let encryptedPayload = try encryptPayload(payload, with: fek)
        let wrappedFEK = try wrapFEK(fek, with: udk)
        let metadata = NoteMetadata(
            noteID: noteID,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
            attachmentCount: UInt32(attachments.count),
            attachmentsTotalSize: attachments.reduce(0) { $0 + UInt64($1.data.count) }
        )
        return try assembleNoteFile(
            metadata: metadata,
            wrappedFEK: wrappedFEK,
            encryptedPayload: encryptedPayload
        )
    }
}

private actor MockNoteRepository: NoteRepository {
    private var notes: [UUID: Data]
    private(set) var deletedNoteIDs: [UUID] = []

    init(notes: [UUID: Data] = [:]) {
        self.notes = notes
    }

    func listNotes() async throws -> [NoteSummary] { [] }

    func readNote(noteID: UUID) async throws -> Data {
        guard let data = notes[noteID] else {
            throw NoteRepositoryError.noteNotFound
        }
        return data
    }

    func writeNote(noteID: UUID, data: Data) async throws {
        notes[noteID] = data
    }

    func deleteNote(noteID: UUID) async throws {
        deletedNoteIDs.append(noteID)
        notes.removeValue(forKey: noteID)
    }

    func noteData(noteID: UUID) async throws -> Data {
        try await readNote(noteID: noteID)
    }
}

private actor MockVaultSession: VaultSessionProtocol {
    private let key: SymmetricKey

    init(udk: SymmetricKey = SymmetricKey(size: .bits256)) {
        key = udk
    }

    var isActive: Bool { true }

    nonisolated var changes: AsyncStream<Bool> {
        AsyncStream { $0.finish() }
    }

    func establish(_ keys: VaultSessionKeys) {}
    func clear() {}
    func udk() throws -> SymmetricKey { key }
    func identityPrivateKey() throws -> Data { Data(repeating: 0x01, count: 32) }
}
