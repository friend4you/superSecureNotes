import NoteRepositoryProtocol
import SecureCrypto
import XCTest

@testable import NoteRepository

final class LocalNoteRepositoryDeleteTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUp() {
        super.setUp()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        temporaryDirectory = nil
        super.tearDown()
    }

    func testDeleteNoteRemovesBodyAttachmentsDirAndIndexRows() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-4466554400a0")!
        let attachmentID = UUID(uuidString: "550e8400-e29b-41d4-a716-4466554400a1")!
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)
        try await NoteTestSupport.openIndexStore(indexStore)

        let note = StoredNote(
            metadata: NoteMetadata(
                noteID: noteID,
                title: "Delete attachments",
                createdAt: 1_700_000_000,
                updatedAt: 1_700_000_100,
                attachmentCount: 1,
                attachmentsTotalSize: 16
            ),
            wrappedFEK: Data(repeating: 0xAB, count: 60),
            encryptedPayload: Data(repeating: 0xCD, count: 64),
            syncState: .synced,
            attachmentCiphertexts: [attachmentID: Data(repeating: 0xEE, count: 16)]
        )
        try await repository.writeNote(note)
        try await indexStore.upsertAttachmentUploadSession(
            AttachmentUploadSessionRecord(
                noteID: noteID,
                attachmentID: attachmentID,
                uploadID: NoteFixtures.uploadID,
                wireSize: 16,
                chunkSize: 8,
                totalChunks: 2
            )
        )

        try await repository.deleteNote(noteID: noteID)

        let noteDir = temporaryDirectory.appendingPathComponent(noteID.uuidString, isDirectory: true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: noteDir.path))

        let attachments = try await indexStore.listAttachments(noteID: noteID)
        XCTAssertEqual(attachments, [])

        let session = try await indexStore.fetchAttachmentUploadSession(
            noteID: noteID,
            attachmentID: attachmentID
        )
        XCTAssertNil(session)

        let pendingRow = try await indexStore.fetchNote(noteID: noteID)
        XCTAssertEqual(pendingRow?.syncState, .pendingDelete)
    }
}
