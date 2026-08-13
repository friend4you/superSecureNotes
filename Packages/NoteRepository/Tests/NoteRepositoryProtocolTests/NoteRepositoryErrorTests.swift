import XCTest

@testable import NoteRepositoryProtocol

final class NoteRepositoryErrorTests: XCTestCase {
    func testErrorCasesAreEquatable() {
        XCTAssertEqual(NoteRepositoryError.notAuthenticated, .notAuthenticated)
        XCTAssertEqual(NoteRepositoryError.noteNotFound, .noteNotFound)
        XCTAssertEqual(NoteRepositoryError.attachmentNotFound("a"), .attachmentNotFound("a"))
        XCTAssertEqual(NoteRepositoryError.userNotFound("u"), .userNotFound("u"))
        XCTAssertEqual(NoteRepositoryError.shareNotFound("s"), .shareNotFound("s"))
        XCTAssertEqual(NoteRepositoryError.alreadyShared("shared"), .alreadyShared("shared"))
        XCTAssertEqual(NoteRepositoryError.conflict("c"), .conflict("c"))
        XCTAssertEqual(NoteRepositoryError.internalError("i"), .internalError("i"))
        XCTAssertEqual(NoteRepositoryError.corruptNote, .corruptNote)
        XCTAssertEqual(NoteRepositoryError.databaseNotOpen, .databaseNotOpen)
        XCTAssertEqual(NoteRepositoryError.notSupported, .notSupported)
        XCTAssertEqual(NoteRepositoryError.validationError("bad"), .validationError("bad"))
        XCTAssertEqual(NoteRepositoryError.networkError, .networkError)
        XCTAssertEqual(
            NoteRepositoryError.serverError(statusCode: 500, message: nil),
            .serverError(statusCode: 500, message: nil)
        )
    }

    func testLocalizedDescriptionUsesBackendMessage() {
        XCTAssertEqual(
            NoteRepositoryError.alreadyShared("Note is already shared with this user.").errorDescription,
            "Note is already shared with this user."
        )
        XCTAssertEqual(
            NoteRepositoryError.serverError(statusCode: 418, message: "Short and stout.").errorDescription,
            "Short and stout."
        )
        XCTAssertEqual(
            NoteRepositoryError.validationError("Cannot share a note with yourself.").errorDescription,
            "Cannot share a note with yourself."
        )
    }
}
