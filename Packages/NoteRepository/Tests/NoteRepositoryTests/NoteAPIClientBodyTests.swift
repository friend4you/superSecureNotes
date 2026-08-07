import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class NoteAPIClientBodyTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testReadBodySendsExpectedRequest() async throws {
        let captured = RequestCapture()
        let noteID = NoteFixtures.noteID
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.noteBytes)
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        let bodyData = try await client.readBody(noteID: noteID, accessToken: NoteFixtures.accessToken)

        XCTAssertEqual(captured.method, "GET")
        XCTAssertEqual(captured.path, "/v1/notes/\(noteID.uuidString.lowercased())/body")
        XCTAssertEqual(captured.authorization, "Bearer \(NoteFixtures.accessToken)")
        XCTAssertEqual(bodyData, NoteFixtures.noteBytes)
    }

    func testWriteBodySendsExpectedRequest() async throws {
        let captured = RequestCapture()
        let noteID = NoteFixtures.noteID
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.writeNoteResponseJSON())
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        _ = try await client.writeBody(
            noteID: noteID,
            data: NoteFixtures.noteBytes,
            accessToken: NoteFixtures.accessToken
        )

        XCTAssertEqual(captured.method, "PUT")
        XCTAssertEqual(captured.path, "/v1/notes/\(noteID.uuidString.lowercased())/body")
        XCTAssertEqual(captured.authorization, "Bearer \(NoteFixtures.accessToken)")
        XCTAssertEqual(captured.contentType, "application/octet-stream")
        XCTAssertEqual(captured.bodyData, NoteFixtures.noteBytes)
        XCTAssertNil(captured.ifMatch)
    }

    func testWriteBodySendsIfMatchWhenProvided() async throws {
        let captured = RequestCapture()
        let etag = #"W/"body-etag""#
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.writeNoteResponseJSON())
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        _ = try await client.writeBody(
            noteID: NoteFixtures.noteID,
            data: NoteFixtures.noteBytes,
            accessToken: NoteFixtures.accessToken,
            ifMatch: etag
        )

        XCTAssertEqual(captured.ifMatch, etag)
    }

    func testWriteBodyParsesUploadResponse() async throws {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (
                response,
                NoteFixtures.writeNoteResponseJSON(
                    syncState: "synced",
                    updatedAt: 1_800_000_000,
                    etag: #"W/"body-server-etag""#
                )
            )
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        let result = try await client.writeBody(
            noteID: NoteFixtures.noteID,
            data: NoteFixtures.noteBytes,
            accessToken: NoteFixtures.accessToken
        )

        XCTAssertEqual(result.syncState, .synced)
        XCTAssertEqual(result.updatedAt, 1_800_000_000)
        XCTAssertEqual(result.etag, #"W/"body-server-etag""#)
    }

    func testListAttachmentsSendsExpectedRequestAndParsesManifest() async throws {
        let captured = RequestCapture()
        let noteID = NoteFixtures.noteID
        let attachmentID = NoteFixtures.attachmentID
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (
                response,
                NoteFixtures.attachmentsManifestJSON(
                    attachments: [
                        (
                            attachmentID: attachmentID,
                            sizeBytes: 4_096,
                            contentType: "application/octet-stream",
                            etag: #"W/"att-etag""#
                        ),
                    ]
                )
            )
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        let attachments = try await client.listAttachments(
            noteID: noteID,
            accessToken: NoteFixtures.accessToken
        )

        XCTAssertEqual(captured.method, "GET")
        XCTAssertEqual(captured.path, "/v1/notes/\(noteID.uuidString.lowercased())/attachments")
        XCTAssertEqual(captured.authorization, "Bearer \(NoteFixtures.accessToken)")
        XCTAssertEqual(attachments.count, 1)
        XCTAssertEqual(attachments[0].attachmentID, attachmentID)
        XCTAssertEqual(attachments[0].sizeBytes, 4_096)
        XCTAssertEqual(attachments[0].contentType, "application/octet-stream")
        XCTAssertEqual(attachments[0].etag, #"W/"att-etag""#)
    }
}
