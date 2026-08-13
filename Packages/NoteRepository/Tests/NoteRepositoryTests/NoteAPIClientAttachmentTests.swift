import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class NoteAPIClientAttachmentTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testListAttachmentsParsesChunkMetadata() async throws {
        let noteID = NoteFixtures.noteID
        let attachmentID = NoteFixtures.attachmentID
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (
                response,
                NoteFixtures.attachmentsManifestJSON(
                    attachments: [
                        (
                            attachmentID: attachmentID,
                            sizeBytes: 4_096,
                            contentType: "application/octet-stream",
                            etag: #"W/"att-etag""#,
                            totalChunks: 2,
                            chunkSize: 2_048
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

        XCTAssertEqual(attachments.count, 1)
        XCTAssertEqual(attachments[0].attachmentID, attachmentID)
        XCTAssertEqual(attachments[0].sizeBytes, 4_096)
        XCTAssertEqual(attachments[0].totalChunks, 2)
        XCTAssertEqual(attachments[0].chunkSize, 2_048)
        XCTAssertEqual(attachments[0].etag, #"W/"att-etag""#)
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
