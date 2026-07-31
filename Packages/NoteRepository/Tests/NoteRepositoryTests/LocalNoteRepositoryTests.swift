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
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)
        let storedNote = NoteTestSupport.makeSampleStoredNote(noteID: noteID, title: "Roundtrip note")

        try await NoteTestSupport.openIndexStore(indexStore)
        try await repository.writeNote(storedNote)
        let readNote = try await repository.readNote(noteID: noteID)

        XCTAssertEqual(readNote.metadata, storedNote.metadata)
        XCTAssertEqual(readNote.wrappedFEK, storedNote.wrappedFEK)
        XCTAssertEqual(readNote.encryptedPayload, storedNote.encryptedPayload)
        XCTAssertEqual(readNote.syncState, .pendingSync)
    }

    func testListNotesFromStoredDirectories() async throws {
        let firstID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440001")!
        let secondID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440002")!
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)

        try await NoteTestSupport.openIndexStore(indexStore)
        try await repository.writeNote(
            NoteTestSupport.makeSampleStoredNote(
                noteID: firstID,
                title: "First note",
                updatedAt: 1_700_000_200
            )
        )
        try await repository.writeNote(
            NoteTestSupport.makeSampleStoredNote(
                noteID: secondID,
                title: "Second note",
                updatedAt: 1_700_000_100
            )
        )

        let summaries = try await repository.listNotes()

        XCTAssertEqual(summaries.count, 2)
        XCTAssertTrue(summaries.contains(NoteSummary(noteID: firstID, title: "First note", updatedAt: 1_700_000_200)))
        XCTAssertTrue(summaries.contains(NoteSummary(noteID: secondID, title: "Second note", updatedAt: 1_700_000_100)))
    }

    func testDeleteNoteRemovesDirectory() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440003")!
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)
        try await NoteTestSupport.openIndexStore(indexStore)
        try await repository.writeNote(
            NoteTestSupport.makeSampleStoredNote(noteID: noteID, title: "Delete me")
        )

        try await repository.deleteNote(noteID: noteID)

        do {
            _ = try await repository.readNote(noteID: noteID)
            XCTFail("Expected noteNotFound after delete")
        } catch NoteRepositoryError.noteNotFound {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testReadNoteWhenDirectoryMissingThrowsNoteNotFound() async throws {
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)
        try await NoteTestSupport.openIndexStore(indexStore)

        do {
            _ = try await repository.readNote(noteID: UUID())
            XCTFail("Expected noteNotFound")
        } catch NoteRepositoryError.noteNotFound {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testReadNoteWhenOnlyNoteFilePresentThrowsCorruptNote() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440004")!
        let noteDirectory = temporaryDirectory.appendingPathComponent(noteID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: noteDirectory, withIntermediateDirectories: true)
        let localBody = try assembleLocalNoteBody(
            metadata: NoteTestSupport.makeSampleStoredNote(noteID: noteID, title: "Incomplete").metadata,
            encryptedPayload: Data(repeating: 0xCD, count: 32)
        )
        try localBody.write(to: noteDirectory.appendingPathComponent("note"))

        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)
        try await NoteTestSupport.openIndexStore(indexStore)

        do {
            _ = try await repository.readNote(noteID: noteID)
            XCTFail("Expected corruptNote")
        } catch NoteRepositoryError.corruptNote {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testWriteNoteRejectsEmptyPayload() async throws {
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)
        try await NoteTestSupport.openIndexStore(indexStore)
        let noteID = UUID()
        let emptyNote = StoredNote(
            metadata: NoteTestSupport.makeSampleStoredNote(noteID: noteID, title: "Empty").metadata,
            wrappedFEK: Data([0x01]),
            encryptedPayload: Data(),
            syncState: .pendingSync
        )

        do {
            try await repository.writeNote(emptyNote)
            XCTFail("Expected validationError")
        } catch NoteRepositoryError.validationError("Note must not be empty.") {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCRUDBeforeIndexStoreOpenThrowsDatabaseNotOpen() async throws {
        let (_, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)
        let noteID = UUID()

        do {
            _ = try await repository.listNotes()
            XCTFail("Expected databaseNotOpen")
        } catch NoteRepositoryError.databaseNotOpen {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        do {
            _ = try await repository.readNote(noteID: noteID)
            XCTFail("Expected databaseNotOpen")
        } catch NoteRepositoryError.databaseNotOpen {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAtomicDirectoryReplaceOnUpdate() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440007")!
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)
        let firstNote = NoteTestSupport.makeSampleStoredNote(
            noteID: noteID,
            title: "First version",
            updatedAt: 1
        )
        let secondNote = NoteTestSupport.makeSampleStoredNote(
            noteID: noteID,
            title: "Second version",
            updatedAt: 2
        )

        try await NoteTestSupport.openIndexStore(indexStore)
        try await repository.writeNote(firstNote)
        try await repository.writeNote(secondNote)
        let readNote = try await repository.readNote(noteID: noteID)

        XCTAssertEqual(readNote.metadata.title, "Second version")
        XCTAssertEqual(readNote.metadata.updatedAt, 2)
    }

    func testNotesRootExcludedFromBackup() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440008")!
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)
        try await NoteTestSupport.openIndexStore(indexStore)
        try await repository.writeNote(
            NoteTestSupport.makeSampleStoredNote(noteID: noteID, title: "Backup exclusion")
        )

        let values = try temporaryDirectory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values.isExcludedFromBackup, true)
    }
}
