import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class NoteAPIClientAttachmentTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testReadAttachmentSendsExpectedRequest() async throws {
        let captured = RequestCapture()
        let noteID = NoteFixtures.noteID
        let attachmentID = NoteFixtures.attachmentID
        let ciphertext = Data(repeating: 0xAB, count: 64)
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, ciphertext)
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        let data = try await client.readAttachment(
            noteID: noteID,
            attachmentID: attachmentID,
            accessToken: NoteFixtures.accessToken
        )

        XCTAssertEqual(captured.method, "GET")
        XCTAssertEqual(
            captured.path,
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())"
        )
        XCTAssertEqual(captured.authorization, "Bearer \(NoteFixtures.accessToken)")
        XCTAssertEqual(data, ciphertext)
    }

    func testWriteAttachmentSendsExpectedRequest() async throws {
        let captured = RequestCapture()
        let noteID = NoteFixtures.noteID
        let attachmentID = NoteFixtures.attachmentID
        let ciphertext = Data(repeating: 0xCD, count: 128)
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.writeAttachmentResponseJSON())
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        _ = try await client.writeAttachment(
            noteID: noteID,
            attachmentID: attachmentID,
            data: ciphertext,
            accessToken: NoteFixtures.accessToken
        )

        XCTAssertEqual(captured.method, "PUT")
        XCTAssertEqual(
            captured.path,
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())"
        )
        XCTAssertEqual(captured.contentType, "application/octet-stream")
        XCTAssertEqual(captured.authorization, "Bearer \(NoteFixtures.accessToken)")
        XCTAssertEqual(captured.bodyData, ciphertext)
        XCTAssertNil(captured.ifMatch)
    }

    func testWriteAttachmentSendsIfMatchWhenProvided() async throws {
        let captured = RequestCapture()
        let etag = #"W/"att-local-etag""#
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.writeAttachmentResponseJSON())
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        _ = try await client.writeAttachment(
            noteID: NoteFixtures.noteID,
            attachmentID: NoteFixtures.attachmentID,
            data: Data([0x01]),
            accessToken: NoteFixtures.accessToken,
            ifMatch: etag
        )

        XCTAssertEqual(captured.ifMatch, etag)
    }

    func testWriteAttachmentParsesResponse() async throws {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (
                response,
                NoteFixtures.writeAttachmentResponseJSON(
                    etag: #"W/"att-server-etag""#,
                    noteEtag: #"W/"note-etag""#
                )
            )
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        let result = try await client.writeAttachment(
            noteID: NoteFixtures.noteID,
            attachmentID: NoteFixtures.attachmentID,
            data: Data([0x01, 0x02]),
            accessToken: NoteFixtures.accessToken
        )

        XCTAssertEqual(result.etag, #"W/"att-server-etag""#)
        XCTAssertEqual(result.noteEtag, #"W/"note-etag""#)
    }

    func testDeleteAttachmentSendsExpectedRequest() async throws {
        let captured = RequestCapture()
        let noteID = NoteFixtures.noteID
        let attachmentID = NoteFixtures.attachmentID
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 204)
            return (response, nil)
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        try await client.deleteAttachment(
            noteID: noteID,
            attachmentID: attachmentID,
            accessToken: NoteFixtures.accessToken
        )

        XCTAssertEqual(captured.method, "DELETE")
        XCTAssertEqual(
            captured.path,
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())"
        )
        XCTAssertEqual(captured.authorization, "Bearer \(NoteFixtures.accessToken)")
    }
}
