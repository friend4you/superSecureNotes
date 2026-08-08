import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class NoteAPIClientListNotesTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testListNotesSendsExpectedRequest() async throws {
        let captured = RequestCapture()
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.listNotesJSON())
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        let notes = try await client.listNotes(accessToken: NoteFixtures.accessToken)

        XCTAssertEqual(captured.method, "GET")
        XCTAssertEqual(captured.path, "/v1/notes")
        XCTAssertEqual(captured.authorization, "Bearer \(NoteFixtures.accessToken)")
        XCTAssertEqual(notes, [NoteFixtures.sampleSummary])
    }

    func testListNotesSendsIncludeDeletedQueryWhenRequested() async throws {
        var capturedURL: URL?
        URLProtocolStub.requestHandler = { request in
            capturedURL = request.url
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.listNotesJSON())
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        _ = try await client.listNotes(accessToken: NoteFixtures.accessToken, includeDeleted: true)

        XCTAssertEqual(capturedURL?.path, "/v1/notes")
        XCTAssertEqual(capturedURL?.query, "includeDeleted=true")
    }

    func testListNotesReturnsEmptyArray() async throws {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.listNotesJSON(summaries: []))
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        let notes = try await client.listNotes(accessToken: NoteFixtures.accessToken)

        XCTAssertTrue(notes.isEmpty)
    }

    func testListNotesMapsUnauthorized() async {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 401)
            return (response, NoteFixtures.errorJSON(error: "unauthorized", message: "Invalid token."))
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())

        do {
            _ = try await client.listNotes(accessToken: NoteFixtures.accessToken)
            XCTFail("Expected notAuthenticated")
        } catch let error as NoteRepositoryError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
