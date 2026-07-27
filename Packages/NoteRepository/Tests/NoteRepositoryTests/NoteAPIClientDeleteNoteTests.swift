import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class NoteAPIClientDeleteNoteTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testDeleteNoteSendsExpectedRequest() async throws {
        let captured = RequestCapture()
        let noteID = NoteFixtures.noteID
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 204)
            return (response, nil)
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        try await client.deleteNote(noteID: noteID, accessToken: NoteFixtures.accessToken)

        XCTAssertEqual(captured.method, "DELETE")
        XCTAssertEqual(captured.path, "/v1/notes/\(noteID.uuidString.lowercased())")
        XCTAssertEqual(captured.authorization, "Bearer \(NoteFixtures.accessToken)")
    }

    func testDeleteNoteMapsNoteNotFound() async {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 404)
            return (response, NoteFixtures.errorJSON(error: "note_not_found", message: "No note."))
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())

        do {
            try await client.deleteNote(noteID: NoteFixtures.noteID, accessToken: NoteFixtures.accessToken)
            XCTFail("Expected noteNotFound")
        } catch let error as NoteRepositoryError {
            XCTAssertEqual(error, .noteNotFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDeleteNoteMapsUnauthorized() async {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 401)
            return (response, NoteFixtures.errorJSON(error: "unauthorized", message: "Invalid token."))
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())

        do {
            try await client.deleteNote(noteID: NoteFixtures.noteID, accessToken: NoteFixtures.accessToken)
            XCTFail("Expected notAuthenticated")
        } catch let error as NoteRepositoryError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
