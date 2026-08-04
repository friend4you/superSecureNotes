import XCTest

@testable import NoteRepositoryProtocol

final class NoteSummaryTests: XCTestCase {
    func testNoteSummaryIsEquatable() {
        let noteID = UUID(uuidString: "550E8400-E29B-41D4-A716-446655440000")!
        let first = NoteSummary(
            noteID: noteID,
            title: "My note",
            updatedAt: 1_700_000_000,
            syncState: .synced
        )
        let second = NoteSummary(
            noteID: noteID,
            title: "My note",
            updatedAt: 1_700_000_000,
            syncState: .synced
        )

        XCTAssertEqual(first.noteID, noteID)
        XCTAssertEqual(first.title, "My note")
        XCTAssertEqual(first.updatedAt, 1_700_000_000)
        XCTAssertEqual(first.syncState, .synced)
        XCTAssertEqual(first, second)
    }

    func testNoteSummaryWithDifferentFieldsIsNotEqual() {
        let noteID = UUID(uuidString: "550E8400-E29B-41D4-A716-446655440000")!
        let first = NoteSummary(noteID: noteID, title: "First", updatedAt: 1, syncState: .synced)
        let second = NoteSummary(noteID: noteID, title: "Second", updatedAt: 2, syncState: .synced)

        XCTAssertNotEqual(first, second)
    }

    func testNoteSummaryWithDifferentSyncStateIsNotEqual() {
        let noteID = UUID(uuidString: "550E8400-E29B-41D4-A716-446655440000")!
        let synced = NoteSummary(noteID: noteID, title: "My note", updatedAt: 1, syncState: .synced)
        let pending = NoteSummary(noteID: noteID, title: "My note", updatedAt: 1, syncState: .pendingSync)

        XCTAssertNotEqual(synced, pending)
    }
}
