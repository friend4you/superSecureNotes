import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class NotesIndexStoreTests: XCTestCase {
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

    func testOpenSetsIsOpen() async throws {
        let store = makeStore()

        let isOpenBefore = await store.isOpen
        XCTAssertFalse(isOpenBefore)

        try await store.open(passphrase: NoteTestSupport.databasePassphrase)

        let isOpenAfter = await store.isOpen
        XCTAssertTrue(isOpenAfter)
    }

    func testCloseClearsIsOpen() async throws {
        let store = makeStore()
        try await store.open(passphrase: NoteTestSupport.databasePassphrase)

        await store.close()

        let isOpenAfter = await store.isOpen
        XCTAssertFalse(isOpenAfter)
    }

    func testDatabaseFileCreatedOnFirstOpen() async throws {
        let store = makeStore()
        let databaseURL = temporaryDirectory.appendingPathComponent("notes.db")

        XCTAssertFalse(FileManager.default.fileExists(atPath: databaseURL.path))

        try await store.open(passphrase: NoteTestSupport.databasePassphrase)

        XCTAssertTrue(FileManager.default.fileExists(atPath: databaseURL.path))
    }

    func testWrongPassphraseFailsToOpenExistingDatabase() async throws {
        let store = makeStore()
        try await store.open(passphrase: NoteTestSupport.databasePassphrase)
        try await store.upsertNote(
            NoteIndexRow(
                storedNote: NoteTestSupport.makeSampleStoredNote(
                    noteID: UUID(),
                    title: "Locked"
                )
            )
        )
        await store.close()

        let reopenedStore = makeStore()
        do {
            try await reopenedStore.open(passphrase: Data([0xFF, 0xFE]))
            XCTFail("Expected open to fail with wrong passphrase")
        } catch {
            let isOpen = await reopenedStore.isOpen
            XCTAssertFalse(isOpen)
        }
    }

    func testClosePreventsQueries() async throws {
        let store = makeStore()
        try await store.open(passphrase: NoteTestSupport.databasePassphrase)
        await store.close()

        do {
            _ = try await store.listSummaries()
            XCTFail("Expected notOpen")
        } catch NotesIndexStoreError.notOpen {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRowRoundtripPreservesFields() async throws {
        let store = makeStore()
        let note = NoteTestSupport.makeSampleStoredNote(
            noteID: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440010")!,
            title: "Indexed note",
            updatedAt: 1_800_000_000,
            syncState: .synced
        )
        try await store.open(passphrase: NoteTestSupport.databasePassphrase)
        try await store.upsertNote(NoteIndexRow(storedNote: note))

        let fetched = try await store.fetchNote(noteID: note.metadata.noteID)

        XCTAssertEqual(fetched?.metadata, note.metadata)
        XCTAssertEqual(fetched?.wrappedFEK, note.wrappedFEK)
        XCTAssertEqual(fetched?.syncState, note.syncState)
    }

    func testNotesIndexStoreErrorIsEquatable() {
        XCTAssertEqual(NotesIndexStoreError.notOpen, .notOpen)
    }

    func testRowRoundtripPreservesEtag() async throws {
        let store = makeStore()
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440011")!
        let row = NoteIndexRow(
            noteID: noteID,
            title: "Etag note",
            createdAt: 1_700_000_000,
            updatedAt: 1_700_000_100,
            attachmentCount: 0,
            attachmentsTotalSize: 0,
            wrappedFEK: Data(repeating: 0xAB, count: 60),
            syncState: .synced,
            etag: "W/\"abc123\""
        )
        try await store.open(passphrase: NoteTestSupport.databasePassphrase)
        try await store.upsertNote(row)

        let fetched = try await store.fetchNote(noteID: noteID)

        XCTAssertEqual(fetched, row)
    }

    func testSyncStateAcceptsPendingDelete() async throws {
        let store = makeStore()
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440012")!
        let row = NoteIndexRow(
            noteID: noteID,
            title: "Pending delete",
            createdAt: 1_700_000_000,
            updatedAt: 1_700_000_100,
            attachmentCount: 0,
            attachmentsTotalSize: 0,
            wrappedFEK: Data(repeating: 0xAB, count: 60),
            syncState: .pendingDelete
        )
        try await store.open(passphrase: NoteTestSupport.databasePassphrase)
        try await store.upsertNote(row)

        let fetched = try await store.fetchNote(noteID: noteID)

        XCTAssertEqual(fetched?.syncState, .pendingDelete)
    }

    func testListSummariesReturnsSyncState() async throws {
        let store = makeStore()
        let syncedID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440013")!
        let pendingID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440014")!
        try await store.open(passphrase: NoteTestSupport.databasePassphrase)
        try await store.upsertNote(
            NoteIndexRow(
                noteID: syncedID,
                title: "Synced",
                createdAt: 1_700_000_000,
                updatedAt: 1_700_000_200,
                attachmentCount: 0,
                attachmentsTotalSize: 0,
                wrappedFEK: Data(repeating: 0xAB, count: 60),
                syncState: .synced
            )
        )
        try await store.upsertNote(
            NoteIndexRow(
                noteID: pendingID,
                title: "Pending",
                createdAt: 1_700_000_000,
                updatedAt: 1_700_000_100,
                attachmentCount: 0,
                attachmentsTotalSize: 0,
                wrappedFEK: Data(repeating: 0xAB, count: 60),
                syncState: .pendingSync
            )
        )

        let summaries = try await store.listSummaries()

        XCTAssertEqual(summaries.count, 2)
        XCTAssertEqual(summaries[0].noteID, syncedID)
        XCTAssertEqual(summaries[0].syncState, .synced)
        XCTAssertEqual(summaries[1].noteID, pendingID)
        XCTAssertEqual(summaries[1].syncState, .pendingSync)
    }

    func testMigrationPreservesExistingRowsWithoutEtag() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440015")!
        try NoteTestSupport.seedLegacyIndexDatabase(
            at: temporaryDirectory,
            passphrase: NoteTestSupport.databasePassphrase,
            noteID: noteID,
            title: "Legacy note"
        )

        let store = makeStore()
        try await store.open(passphrase: NoteTestSupport.databasePassphrase)

        let fetched = try await store.fetchNote(noteID: noteID)

        XCTAssertEqual(fetched?.title, "Legacy note")
        XCTAssertEqual(fetched?.syncState, .synced)
        XCTAssertNil(fetched?.etag)
    }

    private func makeStore() -> NotesIndexStore {
        NotesIndexStore(notesDirectoryURL: temporaryDirectory)
    }
}
