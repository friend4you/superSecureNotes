import NoteRepositoryProtocol
import SecureCrypto
import XCTest

@testable import superSecureNotes

final class FileNoteRepositoryTests: XCTestCase {
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

    func testWriteThenReadNoteRoundtrip() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!
        let repository = FileNoteRepository(directoryURL: temporaryDirectory)
        let blob = try makeSampleNoteFile(noteID: noteID, title: "Roundtrip note")

        try await repository.writeNote(noteID: noteID, data: blob)
        let readBlob = try await repository.readNote(noteID: noteID)

        XCTAssertEqual(readBlob, blob)
    }

    func testListNotesFromStoredFiles() async throws {
        let firstID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440001")!
        let secondID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440002")!
        let repository = FileNoteRepository(directoryURL: temporaryDirectory)

        try await repository.writeNote(
            noteID: firstID,
            data: try makeSampleNoteFile(noteID: firstID, title: "First note", updatedAt: 1_700_000_200)
        )
        try await repository.writeNote(
            noteID: secondID,
            data: try makeSampleNoteFile(noteID: secondID, title: "Second note", updatedAt: 1_700_000_100)
        )

        let summaries = try await repository.listNotes()

        XCTAssertEqual(summaries.count, 2)
        XCTAssertTrue(summaries.contains(NoteSummary(noteID: firstID, title: "First note", updatedAt: 1_700_000_200)))
        XCTAssertTrue(summaries.contains(NoteSummary(noteID: secondID, title: "Second note", updatedAt: 1_700_000_100)))
    }

    func testDeleteNoteRemovesFile() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440003")!
        let repository = FileNoteRepository(directoryURL: temporaryDirectory)
        try await repository.writeNote(
            noteID: noteID,
            data: try makeSampleNoteFile(noteID: noteID, title: "Delete me")
        )

        try await repository.deleteNote(noteID: noteID)

        do {
            _ = try await repository.readNote(noteID: noteID)
            XCTFail("Expected noteNotFound after delete")
        } catch let error as NoteRepositoryError {
            XCTAssertEqual(error, .noteNotFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testReadNoteWhenFileMissingThrowsNoteNotFound() async {
        let repository = FileNoteRepository(directoryURL: temporaryDirectory)

        do {
            _ = try await repository.readNote(noteID: UUID())
            XCTFail("Expected noteNotFound")
        } catch let error as NoteRepositoryError {
            XCTAssertEqual(error, .noteNotFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeSampleNoteFile(
        noteID: UUID,
        title: String,
        updatedAt: UInt64 = 1_700_000_100
    ) throws -> Data {
        let metadata = NoteMetadata(
            noteID: noteID,
            title: title,
            createdAt: 1_700_000_000,
            updatedAt: updatedAt,
            attachmentCount: 0,
            attachmentsTotalSize: 0
        )
        return try assembleNoteFile(
            metadata: metadata,
            wrappedFEK: Data(repeating: 0xAB, count: 60),
            encryptedPayload: Data(repeating: 0xCD, count: 128)
        )
    }
}
