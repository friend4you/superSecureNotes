import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class NoteSharingAPIClientSplitTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testReadSharedBodySendsExpectedRequestAndParsesResponse() async throws {
        let captured = RequestCapture()
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.readSharedBodyJSON())
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        let dto = try await client.readSharedBody(
            noteID: NoteFixtures.noteID,
            accessToken: NoteFixtures.accessToken
        )

        XCTAssertEqual(captured.method, "GET")
        XCTAssertEqual(
            captured.path,
            "/v1/notes/shared/\(NoteFixtures.noteID.uuidString.lowercased())/body"
        )
        XCTAssertEqual(captured.authorization, "Bearer \(NoteFixtures.accessToken)")
        XCTAssertEqual(dto.noteId, NoteFixtures.noteID.uuidString.lowercased())
        XCTAssertEqual(Data(base64Encoded: dto.wrappedFek), NoteFixtures.recipientWrappedFEK)
        XCTAssertEqual(Data(base64Encoded: dto.body), NoteFixtures.noteBytes)
    }

    func testListSharedAttachmentsSendsExpectedRequestAndParsesManifest() async throws {
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
                            sizeBytes: 2_048,
                            contentType: "application/octet-stream",
                            etag: #"W/"shared-att-etag""#
                        ),
                    ]
                )
            )
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        let attachments = try await client.listSharedAttachments(
            noteID: noteID,
            accessToken: NoteFixtures.accessToken
        )

        XCTAssertEqual(captured.method, "GET")
        XCTAssertEqual(
            captured.path,
            "/v1/notes/shared/\(noteID.uuidString.lowercased())/attachments"
        )
        XCTAssertEqual(attachments.count, 1)
        XCTAssertEqual(attachments[0].attachmentID, attachmentID)
        XCTAssertEqual(attachments[0].sizeBytes, 2_048)
        XCTAssertEqual(attachments[0].etag, #"W/"shared-att-etag""#)
    }

    func testReadSharedAttachmentSendsExpectedRequest() async throws {
        let captured = RequestCapture()
        let noteID = NoteFixtures.noteID
        let attachmentID = NoteFixtures.attachmentID
        let ciphertext = Data(repeating: 0xEF, count: 32)
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, ciphertext)
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        let data = try await client.readSharedAttachment(
            noteID: noteID,
            attachmentID: attachmentID,
            accessToken: NoteFixtures.accessToken
        )

        XCTAssertEqual(captured.method, "GET")
        XCTAssertEqual(
            captured.path,
            "/v1/notes/shared/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())"
        )
        XCTAssertEqual(captured.authorization, "Bearer \(NoteFixtures.accessToken)")
        XCTAssertEqual(data, ciphertext)
    }
}
