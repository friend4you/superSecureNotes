import XCTest

@testable import NoteRepositoryProtocol

final class NoteSummaryTests: XCTestCase {
    func testNoteSummaryIsEquatable() {
        let noteID = UUID(uuidString: "550E8400-E29B-41D4-A716-446655440000")!
        let first = NoteSummary(noteID: noteID, title: "My note", updatedAt: 1_700_000_000)
        let second = NoteSummary(noteID: noteID, title: "My note", updatedAt: 1_700_000_000)

        XCTAssertEqual(first.noteID, noteID)
        XCTAssertEqual(first.title, "My note")
        XCTAssertEqual(first.updatedAt, 1_700_000_000)
        XCTAssertEqual(first, second)
    }

    func testNoteSummaryWithDifferentFieldsIsNotEqual() {
        let noteID = UUID(uuidString: "550E8400-E29B-41D4-A716-446655440000")!
        let first = NoteSummary(noteID: noteID, title: "First", updatedAt: 1)
        let second = NoteSummary(noteID: noteID, title: "Second", updatedAt: 2)

        XCTAssertNotEqual(first, second)
    }
}
