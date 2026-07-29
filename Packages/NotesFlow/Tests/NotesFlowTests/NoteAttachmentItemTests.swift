import NotesFlow
import XCTest

@testable import NotesFlow

final class NoteAttachmentItemTests: XCTestCase {
    func testNoteAttachmentItemExposesIdFilenameAndMime() {
        let item = NoteAttachmentItem(
            id: "attachment-1",
            filename: "photo.png",
            mime: "image/png"
        )

        XCTAssertEqual(item.id, "attachment-1")
        XCTAssertEqual(item.filename, "photo.png")
        XCTAssertEqual(item.mime, "image/png")
    }
}
