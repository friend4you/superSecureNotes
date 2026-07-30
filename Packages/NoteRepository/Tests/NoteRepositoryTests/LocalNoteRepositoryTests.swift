import NoteRepositoryProtocol
import SecureCrypto
import XCTest

@testable import NoteRepository

final class LocalNoteRepositoryTests: XCTestCase {
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
        let repository = LocalNoteRepository(notesRootURL: temporaryDirectory)
        let blob = try makeSampleNoteFile(noteID: noteID, title: "Roundtrip note")

        try await repository.writeNote(noteID: noteID, data: blob)
        let readBlob = try await repository.readNote(noteID: noteID)

        XCTAssertEqual(readBlob, blob)
    }

    func testListNotesFromStoredDirectories() async throws {
        let firstID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440001")!
        let secondID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440002")!
        let repository = LocalNoteRepository(notesRootURL: temporaryDirectory)

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

    func testDeleteNoteRemovesDirectory() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440003")!
        let repository = LocalNoteRepository(notesRootURL: temporaryDirectory)
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

    func testReadNoteWhenDirectoryMissingThrowsNoteNotFound() async {
        let repository = LocalNoteRepository(notesRootURL: temporaryDirectory)

        do {
            _ = try await repository.readNote(noteID: UUID())
            XCTFail("Expected noteNotFound")
        } catch let error as NoteRepositoryError {
            XCTAssertEqual(error, .noteNotFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testReadNoteWhenOnlyNoteFilePresentThrowsCorruptNote() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440004")!
        let noteDirectory = temporaryDirectory.appendingPathComponent(noteID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: noteDirectory, withIntermediateDirectories: true)
        let localBody = try assembleLocalNoteBody(
            metadata: makeSampleMetadata(noteID: noteID, title: "Incomplete"),
            encryptedPayload: Data(repeating: 0xCD, count: 32)
        )
        try localBody.write(to: noteDirectory.appendingPathComponent("note"))

        let repository = LocalNoteRepository(notesRootURL: temporaryDirectory)

        do {
            _ = try await repository.readNote(noteID: noteID)
            XCTFail("Expected corruptNote")
        } catch let error as NoteRepositoryError {
            XCTAssertEqual(error, .corruptNote)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testWriteNoteRejectsEmptyData() async {
        let repository = LocalNoteRepository(notesRootURL: temporaryDirectory)

        do {
            try await repository.writeNote(noteID: UUID(), data: Data())
            XCTFail("Expected validationError")
        } catch let error as NoteRepositoryError {
            XCTAssertEqual(error, .validationError("Note must not be empty."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testWriteNoteRejectsNoteIDMismatch() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440005")!
        let otherID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440006")!
        let repository = LocalNoteRepository(notesRootURL: temporaryDirectory)
        let blob = try makeSampleNoteFile(noteID: otherID, title: "Mismatch")

        do {
            try await repository.writeNote(noteID: noteID, data: blob)
            XCTFail("Expected validationError")
        } catch let error as NoteRepositoryError {
            XCTAssertEqual(error, .validationError("Note ID mismatch."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: temporaryDirectory.appendingPathComponent(noteID.uuidString).path
            )
        )
    }

    func testAtomicDirectoryReplaceOnUpdate() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440007")!
        let repository = LocalNoteRepository(notesRootURL: temporaryDirectory)
        let firstBlob = try makeSampleNoteFile(noteID: noteID, title: "First version", updatedAt: 1)
        let secondBlob = try makeSampleNoteFile(noteID: noteID, title: "Second version", updatedAt: 2)

        try await repository.writeNote(noteID: noteID, data: firstBlob)
        try await repository.writeNote(noteID: noteID, data: secondBlob)
        let readBlob = try await repository.readNote(noteID: noteID)

        XCTAssertEqual(readBlob, secondBlob)
    }

    func testNotesRootExcludedFromBackup() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440008")!
        let repository = LocalNoteRepository(notesRootURL: temporaryDirectory)
        try await repository.writeNote(
            noteID: noteID,
            data: try makeSampleNoteFile(noteID: noteID, title: "Backup exclusion")
        )

        let values = try temporaryDirectory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values.isExcludedFromBackup, true)
    }

    private func makeSampleNoteFile(
        noteID: UUID,
        title: String,
        updatedAt: UInt64 = 1_700_000_100
    ) throws -> Data {
        try assembleNoteFile(
            metadata: makeSampleMetadata(noteID: noteID, title: title, updatedAt: updatedAt),
            wrappedFEK: Data(repeating: 0xAB, count: 60),
            encryptedPayload: Data(repeating: 0xCD, count: 128)
        )
    }

    private func makeSampleMetadata(
        noteID: UUID,
        title: String,
        updatedAt: UInt64 = 1_700_000_100
    ) -> NoteMetadata {
        NoteMetadata(
            noteID: noteID,
            title: title,
            createdAt: 1_700_000_000,
            updatedAt: updatedAt,
            attachmentCount: 0,
            attachmentsTotalSize: 0
        )
    }
}
