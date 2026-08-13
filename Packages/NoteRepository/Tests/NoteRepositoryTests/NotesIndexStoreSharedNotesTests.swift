import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class NotesIndexStoreSharedNotesTests: XCTestCase {
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

    func testSharedRowRoundtripPreservesAllFieldsIncludingBodyEtag() async throws {
        let store = makeStore()
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440100")!
        let sharedAt = Date(timeIntervalSince1970: 1_700_000_200)
        let row = SharedNoteIndexRow(
            noteID: noteID,
            title: "Shared note",
            updatedAt: 1_700_000_300,
            etag: #"W/"etag-1""#,
            ownerEmail: "owner@example.com",
            ownerID: UUID(uuidString: "660e8400-e29b-41d4-a716-446655440001")!,
            sharedAt: sharedAt,
            bodyEtag: #"W/"body-etag""#
        )
        try await store.open(passphrase: NoteTestSupport.databasePassphrase)
        try await store.upsertSharedNote(row)

        let fetched = try await store.fetchSharedNote(noteID: noteID)

        XCTAssertEqual(fetched, row)
    }

    func testOwnedAndSharedRowsForSameUUIDCanCoexist() async throws {
        let store = makeStore()
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440101")!
        try await store.open(passphrase: NoteTestSupport.databasePassphrase)
        try await store.upsertNote(
            NoteIndexRow(
                storedNote: NoteTestSupport.makeSampleStoredNote(noteID: noteID, title: "Owned")
            )
        )
        try await store.upsertSharedNote(
            SharedNoteIndexRow(
                noteID: noteID,
                title: "Shared",
                updatedAt: 1_700_000_400,
                etag: #"W/"shared""#,
                ownerEmail: "owner@example.com",
                ownerID: UUID(uuidString: "660e8400-e29b-41d4-a716-446655440002")!,
                sharedAt: Date(timeIntervalSince1970: 1_700_000_400)
            )
        )

        let owned = try await store.fetchNote(noteID: noteID)
        let shared = try await store.fetchSharedNote(noteID: noteID)

        XCTAssertEqual(owned?.title, "Owned")
        XCTAssertEqual(shared?.title, "Shared")
    }

    private func makeStore() -> NotesIndexStore {
        NotesIndexStore(notesDirectoryURL: temporaryDirectory)
    }
}
