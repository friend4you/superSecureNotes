import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class NoteAPIClientErrorMappingTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testMapsAttachmentNotFound() async {
        await assertMappedError(
            statusCode: 404,
            error: "attachment_not_found",
            message: "Attachment not found.",
            expected: .attachmentNotFound("Attachment not found.")
        )
    }

    func testMapsUserNotFound() async {
        await assertMappedError(
            statusCode: 404,
            error: "user_not_found",
            message: "Recipient user not found.",
            expected: .userNotFound("Recipient user not found.")
        )
    }

    func testMapsShareNotFound() async {
        await assertMappedError(
            statusCode: 404,
            error: "share_not_found",
            message: "Share not found.",
            expected: .shareNotFound("Share not found.")
        )
    }

    func testMapsAlreadyShared() async {
        await assertMappedError(
            statusCode: 409,
            error: "already_shared",
            message: "Note is already shared with this user.",
            expected: .alreadyShared("Note is already shared with this user.")
        )
    }

    func testMapsConflict() async {
        await assertMappedError(
            statusCode: 409,
            error: "conflict",
            message: "Note etag does not match.",
            expected: .conflict("Note etag does not match.")
        )
    }

    func testMapsInternalError() async {
        await assertMappedError(
            statusCode: 500,
            error: "internal_error",
            message: "Stored chunk size mismatch.",
            expected: .internalError("Stored chunk size mismatch.")
        )
    }

    func testMapsValidationErrorPreservingMessage() async {
        await assertMappedError(
            statusCode: 400,
            error: "validation_error",
            message: "Cannot share a note with yourself.",
            expected: .validationError("Cannot share a note with yourself.")
        )
    }

    func testUnknownErrorCodeFallsBackToServerErrorWithMessage() async {
        await assertMappedError(
            statusCode: 418,
            error: "teapot",
            message: "Short and stout.",
            expected: .serverError(statusCode: 418, message: "Short and stout.")
        )
    }

    private func assertMappedError(
        statusCode: Int,
        error: String,
        message: String,
        expected: NoteRepositoryError
    ) async {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: statusCode)
            return (response, NoteFixtures.errorJSON(error: error, message: message))
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())

        do {
            try await client.shareNote(
                noteID: NoteFixtures.noteID,
                recipientEmail: "friend@example.com",
                wrappedFEK: Data([0x01]),
                accessToken: NoteFixtures.accessToken
            )
            XCTFail("Expected \(expected)")
        } catch let mapped as NoteRepositoryError {
            XCTAssertEqual(mapped, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
