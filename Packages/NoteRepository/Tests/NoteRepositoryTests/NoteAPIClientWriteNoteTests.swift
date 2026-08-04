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
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.writeNoteResponseJSON())
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        _ = try await client.writeNote(
            noteID: noteID,
            data: NoteFixtures.noteBytes,
            accessToken: NoteFixtures.accessToken
        )

        XCTAssertEqual(captured.method, "PUT")
        XCTAssertEqual(captured.path, "/v1/notes/\(noteID.uuidString.lowercased())")
        XCTAssertEqual(captured.authorization, "Bearer \(NoteFixtures.accessToken)")
        XCTAssertEqual(captured.contentType, "application/octet-stream")
        XCTAssertEqual(captured.bodyData, NoteFixtures.noteBytes)
        XCTAssertNil(captured.ifMatch)
    }

    func testWriteNoteSucceedsOn200WithUploadResponse() async throws {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (
                response,
                NoteFixtures.writeNoteResponseJSON(
                    syncState: "synced",
                    updatedAt: 1_800_000_000,
                    etag: #"W/"server-etag""#
                )
            )
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        let result = try await client.writeNote(
            noteID: NoteFixtures.noteID,
            data: NoteFixtures.noteBytes,
            accessToken: NoteFixtures.accessToken
        )

        XCTAssertEqual(result.syncState, .synced)
        XCTAssertEqual(result.updatedAt, 1_800_000_000)
        XCTAssertEqual(result.etag, #"W/"server-etag""#)
    }

    func testWriteNoteMapsValidationError() async {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 400)
            return (response, NoteFixtures.errorJSON(error: "validation_error", message: "Invalid note."))
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())

        do {
            _ = try await client.writeNote(
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
            _ = try await client.writeNote(
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

    func testWriteNoteRejectsUnexpectedStatusCode() async {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 500)
            return (response, Data())
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())

        do {
            _ = try await client.writeNote(
                noteID: NoteFixtures.noteID,
                data: NoteFixtures.noteBytes,
                accessToken: NoteFixtures.accessToken
            )
            XCTFail("Expected serverError")
        } catch let error as NoteRepositoryError {
            XCTAssertEqual(error, .serverError(statusCode: 500))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testWriteNoteSendsIfMatchHeaderWhenEtagProvided() async throws {
        let captured = RequestCapture()
        let etag = #"W/"local-etag""#
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.writeNoteResponseJSON())
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        _ = try await client.writeNote(
            noteID: NoteFixtures.noteID,
            data: NoteFixtures.noteBytes,
            accessToken: NoteFixtures.accessToken,
            ifMatch: etag
        )

        XCTAssertEqual(captured.ifMatch, etag)
    }

    func testWriteNoteOmitsIfMatchHeaderWhenEtagNotProvided() async throws {
        let captured = RequestCapture()
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.writeNoteResponseJSON())
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        _ = try await client.writeNote(
            noteID: NoteFixtures.noteID,
            data: NoteFixtures.noteBytes,
            accessToken: NoteFixtures.accessToken
        )

        XCTAssertNil(captured.ifMatch)
    }
}
