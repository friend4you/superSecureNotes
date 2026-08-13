import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class LocalNoteRepositorySharedListTests: XCTestCase {
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

    func testListSharedNotesReturnsSummariesFromIndex() async throws {
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)
        try await NoteTestSupport.openIndexStore(indexStore)
        try await indexStore.upsertSharedNote(
            SharedNoteIndexRow(summary: NoteFixtures.sampleSharedSummary)
        )

        let notes = try await repository.listSharedNotes()

        XCTAssertEqual(notes, [NoteFixtures.sampleSharedSummary])
    }

    func testListSharedNotesReturnsEmptyWhenNoShares() async throws {
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)
        try await NoteTestSupport.openIndexStore(indexStore)

        let notes = try await repository.listSharedNotes()

        XCTAssertTrue(notes.isEmpty)
    }

    func testListSharedNotesThrowsWhenIndexClosed() async throws {
        let (_, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)

        do {
            _ = try await repository.listSharedNotes()
            XCTFail("Expected databaseNotOpen")
        } catch NoteRepositoryError.databaseNotOpen {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
