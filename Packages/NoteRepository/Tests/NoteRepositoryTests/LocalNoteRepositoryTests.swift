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

    func testListNotesReturnsSyncStateOnSummaries() async throws {
        let syncedID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440020")!
        let pendingID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440021")!
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)

        try await NoteTestSupport.openIndexStore(indexStore)
        try await repository.writeNote(
            NoteTestSupport.makeSampleStoredNote(
                noteID: syncedID,
                title: "Synced note",
                syncState: .synced
            )
        )
        try await repository.writeNote(
            NoteTestSupport.makeSampleStoredNote(
                noteID: pendingID,
                title: "Pending note"
            )
        )

        let summaries = try await repository.listNotes()

        XCTAssertEqual(summaries.count, 2)
        XCTAssertEqual(
            summaries.first { $0.noteID == syncedID }?.syncState,
            .synced
        )
        XCTAssertEqual(
            summaries.first { $0.noteID == pendingID }?.syncState,
            .pendingSync
        )
    }

    func testListNotesReturnsStoredEtag() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440024")!
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)

        try await NoteTestSupport.openIndexStore(indexStore)
        try await repository.writeNote(
            NoteTestSupport.makeSampleStoredNote(
                noteID: noteID,
                title: "Etag note",
                syncState: .synced
            )
        )
        try await indexStore.upsertNote(
            NoteIndexRow(
                noteID: noteID,
                title: "Etag note",
                createdAt: 1_700_000_000,
                updatedAt: 1_700_000_100,
                attachmentCount: 0,
                attachmentsTotalSize: 0,
                wrappedFEK: Data(repeating: 0xAB, count: 60),
                syncState: .synced,
                etag: #"W/"list-etag""#
            )
        )

        let summaries = try await repository.listNotes()

        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries[0].etag, #"W/"list-etag""#)
    }

    func testWriteNotePreservesStoredEtag() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440025")!
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)

        try await NoteTestSupport.openIndexStore(indexStore)
        try await indexStore.upsertNote(
            NoteIndexRow(
                noteID: noteID,
                title: "Original",
                createdAt: 1_700_000_000,
                updatedAt: 1_700_000_100,
                attachmentCount: 0,
                attachmentsTotalSize: 0,
                wrappedFEK: Data(repeating: 0xAB, count: 60),
                syncState: .synced,
                bodyEtag: #"W/"body-etag""#,
                etag: #"W/"note-etag""#
            )
        )
        try await repository.writeNote(
            NoteTestSupport.makeSampleStoredNote(
                noteID: noteID,
                title: "Updated title",
                syncState: .pendingSync
            )
        )

        let row = try await indexStore.fetchNote(noteID: noteID)
        XCTAssertEqual(row?.etag, #"W/"note-etag""#)
        XCTAssertNil(row?.bodyEtag)
    }

    func testListNotesOmitsPendingDeleteNotes() async throws {
        let visibleID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440022")!
        let deletedID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440023")!
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)

        try await NoteTestSupport.openIndexStore(indexStore)
        try await repository.writeNote(
            NoteTestSupport.makeSampleStoredNote(noteID: visibleID, title: "Visible")
        )
        try await repository.writeNote(
            NoteTestSupport.makeSampleStoredNote(noteID: deletedID, title: "Gone")
        )
        try await repository.deleteNote(noteID: deletedID)

        let summaries = try await repository.listNotes()

        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries[0].noteID, visibleID)
        XCTAssertFalse(summaries.contains { $0.noteID == deletedID })
    }

    func testDeleteNoteEnqueuesRemoteDeleteIntent() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440024")!
        let etag = "W/\"delete-me\""
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)

        try await NoteTestSupport.openIndexStore(indexStore)
        try await repository.writeNote(
            NoteTestSupport.makeSampleStoredNote(
                noteID: noteID,
                title: "Delete me",
                syncState: .synced
            )
        )
        try await indexStore.upsertNote(
            NoteIndexRow(
                noteID: noteID,
                title: "Delete me",
                createdAt: 1_700_000_000,
                updatedAt: 1_700_000_100,
                attachmentCount: 0,
                attachmentsTotalSize: 0,
                wrappedFEK: Data(repeating: 0xAB, count: 60),
                syncState: .synced,
                etag: etag
            )
        )

        try await repository.deleteNote(noteID: noteID)

        let summaries = try await repository.listNotes()
        XCTAssertTrue(summaries.isEmpty)

        let pendingRow = try await indexStore.fetchNote(noteID: noteID)
        XCTAssertEqual(pendingRow?.syncState, .pendingDelete)
        XCTAssertEqual(pendingRow?.etag, etag)

        let noteDirectoryURL = temporaryDirectory.appendingPathComponent(noteID.uuidString, isDirectory: true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: noteDirectoryURL.path))

        do {
            _ = try await repository.readNote(noteID: noteID)
            XCTFail("Expected noteNotFound after delete")
        } catch NoteRepositoryError.noteNotFound {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
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
        XCTAssertTrue(summaries.contains(
            NoteSummary(
                noteID: firstID,
                title: "First note",
                updatedAt: 1_700_000_200,
                syncState: .pendingSync
            )
        ))
        XCTAssertTrue(summaries.contains(
            NoteSummary(
                noteID: secondID,
                title: "Second note",
                updatedAt: 1_700_000_100,
                syncState: .pendingSync
            )
        ))
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

    func testReadNoteWhenBodyFileMissingThrowsCorruptNote() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440004")!
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)
        try await NoteTestSupport.openIndexStore(indexStore)
        try await repository.writeNote(
            NoteTestSupport.makeSampleStoredNote(noteID: noteID, title: "Incomplete")
        )

        let bodyURL = temporaryDirectory
            .appendingPathComponent(noteID.uuidString, isDirectory: true)
            .appendingPathComponent("body")
        try FileManager.default.removeItem(at: bodyURL)

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
