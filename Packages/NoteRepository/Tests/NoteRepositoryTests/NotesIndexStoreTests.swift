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

    private func makeStore() -> NotesIndexStore {
        NotesIndexStore(notesDirectoryURL: temporaryDirectory)
    }
}
