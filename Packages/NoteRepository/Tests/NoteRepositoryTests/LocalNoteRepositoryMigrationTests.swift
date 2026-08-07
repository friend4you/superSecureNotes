import CryptoKit
import NoteRepositoryProtocol
import SecureCrypto
import XCTest

@testable import NoteRepository

final class LocalNoteRepositoryMigrationTests: XCTestCase {
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

    func testLegacyPayloadFileMigratesToBodyOnRead() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440090")!
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)
        try await NoteTestSupport.openIndexStore(indexStore)

        let note = NoteTestSupport.makeSampleStoredNote(noteID: noteID, title: "Legacy layout")
        try await indexStore.upsertNote(NoteIndexRow(storedNote: note))

        let noteDir = temporaryDirectory.appendingPathComponent(noteID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: noteDir, withIntermediateDirectories: true)
        let payloadURL = noteDir.appendingPathComponent("payload")
        try writeNotePayloadFile(note.encryptedPayload, to: payloadURL)

        let read = try await repository.readNote(noteID: noteID)

        XCTAssertEqual(read.encryptedPayload, note.encryptedPayload)
        XCTAssertEqual(read.wrappedFEK, note.wrappedFEK)

        let bodyURL = noteDir.appendingPathComponent("body")
        XCTAssertTrue(FileManager.default.fileExists(atPath: bodyURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: payloadURL.path))

        let sections = try parseNoteFile(try Data(contentsOf: bodyURL))
        XCTAssertEqual(sections.encryptedPayload, note.encryptedPayload)
        XCTAssertEqual(sections.metadata.title, "Legacy layout")
    }

    func testMigrateInlineAttachmentsToSplitRewritesBodyAndFiles() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440091")!
        let udk = SymmetricKey(size: .bits256)
        let fek = generateSymmetricKey()
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)
        try await NoteTestSupport.openIndexStore(indexStore)

        let v1Payload = NotePayload(
            body: Data("legacy body".utf8),
            attachments: [
                NotePayload.Attachment(
                    id: "legacy-att-id",
                    filename: "photo.png",
                    mime: "image/png",
                    data: Data([0x89, 0x50, 0x4E, 0x47])
                ),
            ]
        )
        let encryptedPayload = try encryptPayload(v1Payload, with: fek)
        let wrappedFEK = try wrapFEK(fek, with: udk)
        let note = StoredNote(
            metadata: NoteMetadata(
                noteID: noteID,
                title: "V1 note",
                createdAt: 1_700_000_000,
                updatedAt: 1_700_000_100,
                attachmentCount: 1,
                attachmentsTotalSize: 4
            ),
            wrappedFEK: wrappedFEK,
            encryptedPayload: encryptedPayload,
            syncState: .synced
        )
        try await repository.writeNote(note)

        try await repository.migrateInlineAttachmentsToSplit(noteID: noteID, fek: fek)

        let migrated = try await repository.readNote(noteID: noteID)
        XCTAssertEqual(migrated.syncState, .pendingSync)
        XCTAssertEqual(migrated.attachmentCiphertexts.count, 1)

        let decrypted = try decryptPayload(migrated.encryptedPayload, with: fek)
        XCTAssertEqual(decrypted.schemaVersion, 2)
        XCTAssertEqual(decrypted.attachments.count, 1)
        XCTAssertNil(decrypted.attachments[0].data)
        XCTAssertNotEqual(decrypted.attachments[0].id, "legacy-att-id")
        XCTAssertNotNil(UUID(uuidString: decrypted.attachments[0].id))

        let attachmentID = UUID(uuidString: decrypted.attachments[0].id)!
        let ciphertext = try XCTUnwrap(migrated.attachmentCiphertexts[attachmentID])
        let plaintext = try decryptAttachmentFile(ciphertext, with: fek)
        XCTAssertEqual(plaintext, Data([0x89, 0x50, 0x4E, 0x47]))

        let noteDir = temporaryDirectory.appendingPathComponent(noteID.uuidString, isDirectory: true)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: noteDir
                    .appendingPathComponent("attachments")
                    .appendingPathComponent(attachmentID.uuidString)
                    .path
            )
        )
    }
}
