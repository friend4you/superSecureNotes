import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class NoteAPIClientWriteNoteTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testWriteNoteSendsExpectedRequest() async throws {
        let captured = RequestCapture()
        let noteID = NoteFixtures.noteID
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 204)
            return (response, nil)
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        try await client.writeNote(
            noteID: noteID,
            data: NoteFixtures.noteBytes,
            accessToken: NoteFixtures.accessToken
        )

        XCTAssertEqual(captured.method, "PUT")
        XCTAssertEqual(captured.path, "/v1/notes/\(noteID.uuidString.lowercased())")
        XCTAssertEqual(captured.authorization, "Bearer \(NoteFixtures.accessToken)")
        XCTAssertEqual(captured.contentType, "application/octet-stream")
        XCTAssertEqual(captured.bodyData, NoteFixtures.noteBytes)
    }

    func testWriteNoteMapsValidationError() async {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 400)
            return (response, NoteFixtures.errorJSON(error: "validation_error", message: "Invalid note."))
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())

        do {
            try await client.writeNote(
                noteID: NoteFixtures.noteID,
                data: NoteFixtures.noteBytes,
                accessToken: NoteFixtures.accessToken
            )
            XCTFail("Expected validationError")
        } catch let error as NoteRepositoryError {
            XCTAssertEqual(error, .validationError("Invalid note."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testWriteNoteMapsUnauthorized() async {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 401)
            return (response, NoteFixtures.errorJSON(error: "unauthorized", message: "Invalid token."))
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())

        do {
            try await client.writeNote(
                noteID: NoteFixtures.noteID,
                data: NoteFixtures.noteBytes,
                accessToken: NoteFixtures.accessToken
            )
            XCTFail("Expected notAuthenticated")
        } catch let error as NoteRepositoryError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
