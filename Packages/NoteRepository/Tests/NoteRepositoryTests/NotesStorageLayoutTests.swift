import CryptoKit
import NoteRepositoryProtocol
import SecureCrypto
import XCTest

@testable import NoteRepository

final class NotesStorageLayoutTests: XCTestCase {
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

    func testWriteCreatesNotesDatabaseAndBodyWithoutPlaintextBody() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440010")!
        let title = "Secret Meeting Notes"
        let body = "Discuss quarterly roadmap"
        let udk = SymmetricKey(size: .bits256)
        let fek = generateSymmetricKey()
        let encryptedPayload = try encryptPayload(
            NotePayload(body: Data(body.utf8)),
            with: fek
        )
        let storedNote = StoredNote(
            metadata: NoteMetadata(
                noteID: noteID,
                title: title,
                createdAt: 1_700_000_000,
                updatedAt: 1_700_000_100,
                attachmentCount: 0,
                attachmentsTotalSize: 0
            ),
            wrappedFEK: try wrapFEK(fek, with: udk),
            encryptedPayload: encryptedPayload,
            syncState: .pendingSync
        )

        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)
        try await indexStore.open(passphrase: deriveNotesDatabaseKey(from: udk))
        try await repository.writeNote(storedNote)

        let databaseURL = temporaryDirectory.appendingPathComponent("notes.db")
        let bodyURL = temporaryDirectory
            .appendingPathComponent(noteID.uuidString, isDirectory: true)
            .appendingPathComponent("body")
        let bodyData = try Data(contentsOf: bodyURL)
        let sections = try parseNoteFile(bodyData)

        XCTAssertTrue(FileManager.default.fileExists(atPath: databaseURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: bodyURL.path))
        // Title is plaintext in SSNT metadata; note body text must stay in ciphertext only.
        XCTAssertNotNil(bodyData.range(of: Data(title.utf8)))
        XCTAssertNil(sections.encryptedPayload.range(of: Data(body.utf8)))
        XCTAssertNil(bodyData.range(of: Data(body.utf8)))
    }
}
