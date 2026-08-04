import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class NotesIndexStoreUploadSessionTests: XCTestCase {
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

    func testUploadSessionRoundtripPreservesFields() async throws {
        let store = makeStore()
        let record = sampleSession(completedChunkIndices: [0, 2])
        try await store.open(passphrase: NoteTestSupport.databasePassphrase)

        try await store.upsertUploadSession(record)

        let fetched = try await store.fetchUploadSession(noteID: record.noteID)
        XCTAssertEqual(fetched, record)
    }

    func testUploadSessionSurvivesCloseAndReopen() async throws {
        let store = makeStore()
        let record = sampleSession(completedChunkIndices: [1])
        try await store.open(passphrase: NoteTestSupport.databasePassphrase)
        try await store.upsertUploadSession(record)
        await store.close()

        try await store.open(passphrase: NoteTestSupport.databasePassphrase)
        let fetched = try await store.fetchUploadSession(noteID: record.noteID)
        XCTAssertEqual(fetched, record)
    }

    func testMarkUploadChunkCompletedUpdatesPersistedIndices() async throws {
        let store = makeStore()
        let record = sampleSession()
        try await store.open(passphrase: NoteTestSupport.databasePassphrase)
        try await store.upsertUploadSession(record)

        try await store.markUploadChunkCompleted(noteID: record.noteID, chunkIndex: 0)
        try await store.markUploadChunkCompleted(noteID: record.noteID, chunkIndex: 2)

        let fetched = try await store.fetchUploadSession(noteID: record.noteID)
        XCTAssertEqual(fetched?.completedChunkIndices, [0, 2])
    }

    func testDeleteUploadSessionRemovesRow() async throws {
        let store = makeStore()
        let record = sampleSession()
        try await store.open(passphrase: NoteTestSupport.databasePassphrase)
        try await store.upsertUploadSession(record)

        try await store.deleteUploadSession(noteID: record.noteID)

        let fetched = try await store.fetchUploadSession(noteID: record.noteID)
        XCTAssertNil(fetched)
    }

    private func makeStore() -> NotesIndexStore {
        NotesIndexStore(notesDirectoryURL: temporaryDirectory)
    }

    private func sampleSession(completedChunkIndices: Set<Int> = []) -> NoteUploadSessionRecord {
        NoteUploadSessionRecord(
            noteID: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440050")!,
            uploadID: NoteFixtures.uploadID,
            wireSize: NoteUploadSizeThreshold + 1,
            chunkSize: 5_000_000,
            totalChunks: 3,
            completedChunkIndices: completedChunkIndices,
            ifMatch: #"W/"session-etag""#
        )
    }
}
