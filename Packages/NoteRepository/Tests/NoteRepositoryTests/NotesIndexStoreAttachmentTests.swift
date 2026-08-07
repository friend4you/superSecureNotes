import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class NotesIndexStoreAttachmentTests: XCTestCase {
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

    func testNoteRowRoundtripPreservesBodyEtagAndEtag() async throws {
        let store = makeStore()
        try await store.open(passphrase: NoteTestSupport.databasePassphrase)

        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440060")!
        let row = NoteIndexRow(
            noteID: noteID,
            title: "Split note",
            createdAt: 1_700_000_000,
            updatedAt: 1_700_000_100,
            attachmentCount: 1,
            attachmentsTotalSize: 42,
            wrappedFEK: Data(repeating: 0xAB, count: 48),
            syncState: .pendingSync,
            bodyEtag: #"W/"body-etag-1""#,
            etag: #"W/"list-etag-1""#
        )

        try await store.upsertNote(row)

        let fetched = try await store.fetchNote(noteID: noteID)
        XCTAssertEqual(fetched, row)
        XCTAssertEqual(fetched?.bodyEtag, #"W/"body-etag-1""#)
        XCTAssertEqual(fetched?.etag, #"W/"list-etag-1""#)
    }

    func testAttachmentRowRoundtripByNoteAndAttachmentID() async throws {
        let store = makeStore()
        try await store.open(passphrase: NoteTestSupport.databasePassphrase)

        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440061")!
        let attachmentID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440062")!
        let row = AttachmentIndexRow(
            noteID: noteID,
            attachmentID: attachmentID,
            etag: #"W/"att-etag""#,
            sizeBytes: 12_345,
            syncState: .pendingSync
        )

        try await store.upsertAttachment(row)

        let fetched = try await store.fetchAttachment(noteID: noteID, attachmentID: attachmentID)
        XCTAssertEqual(fetched, row)
    }

    func testListAttachmentsReturnsRowsForNote() async throws {
        let store = makeStore()
        try await store.open(passphrase: NoteTestSupport.databasePassphrase)

        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440063")!
        let otherNoteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440064")!
        let first = AttachmentIndexRow(
            noteID: noteID,
            attachmentID: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440065")!,
            sizeBytes: 10,
            syncState: .synced
        )
        let second = AttachmentIndexRow(
            noteID: noteID,
            attachmentID: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440066")!,
            etag: #"W/"second""#,
            sizeBytes: 20,
            syncState: .pendingSync
        )
        let other = AttachmentIndexRow(
            noteID: otherNoteID,
            attachmentID: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440067")!,
            sizeBytes: 30,
            syncState: .synced
        )

        try await store.upsertAttachment(first)
        try await store.upsertAttachment(second)
        try await store.upsertAttachment(other)

        let listed = try await store.listAttachments(noteID: noteID)
        XCTAssertEqual(listed, [first, second])
    }

    func testDeleteAttachmentRemovesSingleRow() async throws {
        let store = makeStore()
        try await store.open(passphrase: NoteTestSupport.databasePassphrase)

        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440068")!
        let keepID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440069")!
        let removeID = UUID(uuidString: "550e8400-e29b-41d4-a716-44665544006a")!
        try await store.upsertAttachment(
            AttachmentIndexRow(noteID: noteID, attachmentID: keepID, sizeBytes: 1, syncState: .synced)
        )
        try await store.upsertAttachment(
            AttachmentIndexRow(noteID: noteID, attachmentID: removeID, sizeBytes: 2, syncState: .synced)
        )

        try await store.deleteAttachment(noteID: noteID, attachmentID: removeID)

        let removed = try await store.fetchAttachment(noteID: noteID, attachmentID: removeID)
        let kept = try await store.fetchAttachment(noteID: noteID, attachmentID: keepID)
        XCTAssertNil(removed)
        XCTAssertNotNil(kept)
    }

    func testDeleteAttachmentsRemovesAllForNote() async throws {
        let store = makeStore()
        try await store.open(passphrase: NoteTestSupport.databasePassphrase)

        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-44665544006b")!
        try await store.upsertAttachment(
            AttachmentIndexRow(
                noteID: noteID,
                attachmentID: UUID(uuidString: "550e8400-e29b-41d4-a716-44665544006c")!,
                sizeBytes: 1,
                syncState: .synced
            )
        )
        try await store.upsertAttachment(
            AttachmentIndexRow(
                noteID: noteID,
                attachmentID: UUID(uuidString: "550e8400-e29b-41d4-a716-44665544006d")!,
                sizeBytes: 2,
                syncState: .pendingSync
            )
        )

        try await store.deleteAttachments(noteID: noteID)

        let listed = try await store.listAttachments(noteID: noteID)
        XCTAssertEqual(listed, [])
    }

    private func makeStore() -> NotesIndexStore {
        NotesIndexStore(notesDirectoryURL: temporaryDirectory)
    }
}
