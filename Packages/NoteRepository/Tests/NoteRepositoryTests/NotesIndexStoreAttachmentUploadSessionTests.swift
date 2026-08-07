import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class NotesIndexStoreAttachmentUploadSessionTests: XCTestCase {
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

    func testAttachmentUploadSessionRoundtripKeyedByNoteAndAttachment() async throws {
        let store = makeStore()
        let record = sampleSession(completedChunkIndices: [0, 2])
        try await store.open(passphrase: NoteTestSupport.databasePassphrase)

        try await store.upsertAttachmentUploadSession(record)

        let fetched = try await store.fetchAttachmentUploadSession(
            noteID: record.noteID,
            attachmentID: record.attachmentID
        )
        XCTAssertEqual(fetched, record)
    }

    func testAttachmentUploadSessionSurvivesCloseAndReopen() async throws {
        let store = makeStore()
        let record = sampleSession(completedChunkIndices: [1])
        try await store.open(passphrase: NoteTestSupport.databasePassphrase)
        try await store.upsertAttachmentUploadSession(record)
        await store.close()

        try await store.open(passphrase: NoteTestSupport.databasePassphrase)
        let fetched = try await store.fetchAttachmentUploadSession(
            noteID: record.noteID,
            attachmentID: record.attachmentID
        )
        XCTAssertEqual(fetched, record)
    }

    func testMarkAttachmentUploadChunkCompletedUpdatesPersistedIndices() async throws {
        let store = makeStore()
        let record = sampleSession()
        try await store.open(passphrase: NoteTestSupport.databasePassphrase)
        try await store.upsertAttachmentUploadSession(record)

        try await store.markAttachmentUploadChunkCompleted(
            noteID: record.noteID,
            attachmentID: record.attachmentID,
            chunkIndex: 0
        )
        try await store.markAttachmentUploadChunkCompleted(
            noteID: record.noteID,
            attachmentID: record.attachmentID,
            chunkIndex: 2
        )

        let fetched = try await store.fetchAttachmentUploadSession(
            noteID: record.noteID,
            attachmentID: record.attachmentID
        )
        XCTAssertEqual(fetched?.completedChunkIndices, [0, 2])
    }

    func testDeleteAttachmentUploadSessionRemovesRow() async throws {
        let store = makeStore()
        let record = sampleSession()
        try await store.open(passphrase: NoteTestSupport.databasePassphrase)
        try await store.upsertAttachmentUploadSession(record)

        try await store.deleteAttachmentUploadSession(
            noteID: record.noteID,
            attachmentID: record.attachmentID
        )

        let fetched = try await store.fetchAttachmentUploadSession(
            noteID: record.noteID,
            attachmentID: record.attachmentID
        )
        XCTAssertNil(fetched)
    }

    func testSessionsForDifferentAttachmentsAreIndependent() async throws {
        let store = makeStore()
        try await store.open(passphrase: NoteTestSupport.databasePassphrase)

        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440070")!
        let first = sampleSession(
            noteID: noteID,
            attachmentID: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440071")!,
            completedChunkIndices: [0]
        )
        let second = sampleSession(
            noteID: noteID,
            attachmentID: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440072")!,
            completedChunkIndices: [1, 2]
        )

        try await store.upsertAttachmentUploadSession(first)
        try await store.upsertAttachmentUploadSession(second)

        let fetchedFirst = try await store.fetchAttachmentUploadSession(
            noteID: noteID,
            attachmentID: first.attachmentID
        )
        let fetchedSecond = try await store.fetchAttachmentUploadSession(
            noteID: noteID,
            attachmentID: second.attachmentID
        )
        XCTAssertEqual(fetchedFirst, first)
        XCTAssertEqual(fetchedSecond, second)
    }

    private func makeStore() -> NotesIndexStore {
        NotesIndexStore(notesDirectoryURL: temporaryDirectory)
    }

    private func sampleSession(
        noteID: UUID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440050")!,
        attachmentID: UUID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440051")!,
        completedChunkIndices: Set<Int> = []
    ) -> AttachmentUploadSessionRecord {
        AttachmentUploadSessionRecord(
            noteID: noteID,
            attachmentID: attachmentID,
            uploadID: NoteFixtures.uploadID,
            wireSize: NoteUploadSizeThreshold + 1,
            chunkSize: 5_000_000,
            totalChunks: 3,
            completedChunkIndices: completedChunkIndices,
            ifMatch: #"W/"attachment-session-etag""#
        )
    }
}
