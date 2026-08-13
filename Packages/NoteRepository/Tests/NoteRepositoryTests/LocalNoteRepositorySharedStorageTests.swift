import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class LocalNoteRepositorySharedStorageTests: XCTestCase {
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

    func testSharedBodyWriteReadUsesSharedDirectory() async throws {
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)
        try await NoteTestSupport.openIndexStore(indexStore)
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440200")!
        let bodyData = NoteFixtures.noteBytes

        try await repository.writeSharedBodyFileForTest(bodyData, noteID: noteID)
        let readBack = try await repository.readSharedBodyFileForTest(noteID: noteID)

        let sharedBodyURL = temporaryDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("shared", isDirectory: true)
            .appendingPathComponent(noteID.uuidString, isDirectory: true)
            .appendingPathComponent("body")
        let ownedBodyURL = temporaryDirectory
            .appendingPathComponent(noteID.uuidString, isDirectory: true)
            .appendingPathComponent("body")

        XCTAssertEqual(readBack, bodyData)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sharedBodyURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: ownedBodyURL.path))
    }

    func testSharedAttachmentWriteReadUsesSharedDirectory() async throws {
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)
        try await NoteTestSupport.openIndexStore(indexStore)
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440201")!
        let attachmentID = UUID(uuidString: "880e8400-e29b-41d4-a716-446655440201")!
        let ciphertext = Data(repeating: 0x77, count: 32)

        try await repository.persistSharedAttachmentCiphertextForTest(
            noteID: noteID,
            attachmentID: attachmentID,
            ciphertext: ciphertext
        )
        let readBack = try await repository.readSharedAttachmentCiphertext(
            noteID: noteID,
            attachmentID: attachmentID
        )

        let sharedAttachmentURL = temporaryDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("shared", isDirectory: true)
            .appendingPathComponent(noteID.uuidString, isDirectory: true)
            .appendingPathComponent("attachments", isDirectory: true)
            .appendingPathComponent(attachmentID.uuidString)
        let ownedAttachmentURL = temporaryDirectory
            .appendingPathComponent(noteID.uuidString, isDirectory: true)
            .appendingPathComponent("attachments", isDirectory: true)
            .appendingPathComponent(attachmentID.uuidString)

        XCTAssertEqual(readBack, ciphertext)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sharedAttachmentURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: ownedAttachmentURL.path))
    }
}

private extension LocalNoteRepository {
    func writeSharedBodyFileForTest(_ bodyData: Data, noteID: UUID) throws {
        try writeSharedBodyFile(bodyData, noteID: noteID)
    }

    func readSharedBodyFileForTest(noteID: UUID) throws -> Data {
        try readSharedBodyFile(noteID: noteID)
    }

    func persistSharedAttachmentCiphertextForTest(
        noteID: UUID,
        attachmentID: UUID,
        ciphertext: Data
    ) throws {
        try persistSharedAttachmentCiphertext(
            noteID: noteID,
            attachmentID: attachmentID,
            ciphertext: ciphertext
        )
    }
}
