import XCTest

@testable import NoteRepositoryProtocol

final class NoteRepositoryErrorTests: XCTestCase {
    func testErrorCasesAreEquatable() {
        XCTAssertEqual(NoteRepositoryError.notAuthenticated, .notAuthenticated)
        XCTAssertEqual(NoteRepositoryError.noteNotFound, .noteNotFound)
        XCTAssertEqual(NoteRepositoryError.corruptNote, .corruptNote)
        XCTAssertEqual(NoteRepositoryError.databaseNotOpen, .databaseNotOpen)
        XCTAssertEqual(NoteRepositoryError.notSupported, .notSupported)
        XCTAssertEqual(NoteRepositoryError.validationError("bad"), .validationError("bad"))
        XCTAssertEqual(NoteRepositoryError.networkError, .networkError)
        XCTAssertEqual(NoteRepositoryError.serverError(statusCode: 500), .serverError(statusCode: 500))
    }
}
