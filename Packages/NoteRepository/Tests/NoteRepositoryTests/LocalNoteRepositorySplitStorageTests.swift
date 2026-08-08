import CryptoKit
import NoteRepositoryProtocol
import SecureCrypto
import XCTest

@testable import NoteRepository

final class LocalNoteRepositorySplitStorageTests: XCTestCase {
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

    func testWriteStoresBodyAndAttachmentCiphertextFiles() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440080")!
        let firstAttachmentID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440081")!
        let secondAttachmentID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440082")!
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)
        try await NoteTestSupport.openIndexStore(indexStore)

        let firstCiphertext = Data(repeating: 0x11, count: 32)
        let secondCiphertext = Data(repeating: 0x22, count: 64)
        let note = makeSplitNote(
            noteID: noteID,
            attachmentCiphertexts: [
                firstAttachmentID: firstCiphertext,
                secondAttachmentID: secondCiphertext,
            ]
        )

        try await repository.writeNote(note)

        let noteDir = temporaryDirectory.appendingPathComponent(noteID.uuidString, isDirectory: true)
        let bodyURL = noteDir.appendingPathComponent("body")
        let firstURL = noteDir
            .appendingPathComponent("attachments", isDirectory: true)
            .appendingPathComponent(firstAttachmentID.uuidString)
        let secondURL = noteDir
            .appendingPathComponent("attachments", isDirectory: true)
            .appendingPathComponent(secondAttachmentID.uuidString)

        XCTAssertTrue(FileManager.default.fileExists(atPath: bodyURL.path))
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: noteDir.appendingPathComponent("payload").path
            )
        )
        XCTAssertEqual(try Data(contentsOf: firstURL), firstCiphertext)
        XCTAssertEqual(try Data(contentsOf: secondURL), secondCiphertext)

        let sections = try parseNoteFile(try Data(contentsOf: bodyURL))
        XCTAssertEqual(sections.encryptedPayload, note.encryptedPayload)
        XCTAssertEqual(sections.wrappedFEK, note.wrappedFEK)
        XCTAssertEqual(sections.metadata.noteID, noteID)
    }

    func testReadAssemblesStoredNoteFromSplitFiles() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440083")!
        let attachmentID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440084")!
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)
        try await NoteTestSupport.openIndexStore(indexStore)

        let ciphertext = Data(repeating: 0x33, count: 48)
        let note = makeSplitNote(
            noteID: noteID,
            attachmentCiphertexts: [attachmentID: ciphertext]
        )
        try await repository.writeNote(note)

        let read = try await repository.readNote(noteID: noteID)

        XCTAssertEqual(read.metadata, note.metadata)
        XCTAssertEqual(read.wrappedFEK, note.wrappedFEK)
        XCTAssertEqual(read.encryptedPayload, note.encryptedPayload)
        XCTAssertEqual(read.attachmentCiphertexts, [attachmentID: ciphertext])
        XCTAssertEqual(read.syncState, .pendingSync)

        let rows = try await indexStore.listAttachments(noteID: noteID)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].attachmentID, attachmentID)
        XCTAssertEqual(rows[0].sizeBytes, UInt64(ciphertext.count))
        XCTAssertEqual(rows[0].syncState, .pendingSync)
    }

    func testWriteNormalizesAttachmentManifestFromCiphertextSizes() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440085")!
        let attachmentID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440086")!
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)
        try await NoteTestSupport.openIndexStore(indexStore)

        let ciphertext = Data(repeating: 0x44, count: 48)
        let note = StoredNote(
            metadata: NoteMetadata(
                noteID: noteID,
                title: "Plaintext manifest",
                createdAt: 1_700_000_000,
                updatedAt: 1_700_000_100,
                attachmentCount: 1,
                attachmentsTotalSize: 10
            ),
            wrappedFEK: Data(repeating: 0xAB, count: 60),
            encryptedPayload: Data(repeating: 0xCD, count: 128),
            syncState: .pendingSync,
            attachmentCiphertexts: [attachmentID: ciphertext]
        )

        try await repository.writeNote(note)

        let read = try await repository.readNote(noteID: noteID)
        XCTAssertEqual(read.metadata.attachmentCount, 1)
        XCTAssertEqual(read.metadata.attachmentsTotalSize, UInt64(ciphertext.count))

        let bodyURL = temporaryDirectory
            .appendingPathComponent(noteID.uuidString, isDirectory: true)
            .appendingPathComponent("body")
        let sections = try parseNoteFile(try Data(contentsOf: bodyURL))
        XCTAssertEqual(sections.metadata.attachmentsTotalSize, UInt64(ciphertext.count))
    }

    private func makeSplitNote(
        noteID: UUID,
        attachmentCiphertexts: [UUID: Data]
    ) -> StoredNote {
        let totalSize = attachmentCiphertexts.values.reduce(0) { $0 + UInt64($1.count) }
        return StoredNote(
            metadata: NoteMetadata(
                noteID: noteID,
                title: "Split note",
                createdAt: 1_700_000_000,
                updatedAt: 1_700_000_100,
                attachmentCount: UInt32(attachmentCiphertexts.count),
                attachmentsTotalSize: totalSize
            ),
            wrappedFEK: Data(repeating: 0xAB, count: 60),
            encryptedPayload: Data(repeating: 0xCD, count: 128),
            syncState: .pendingSync,
            attachmentCiphertexts: attachmentCiphertexts
        )
    }
}
