import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class NoteAPIClientAttachmentChunkDownloadTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testReadAttachmentChunkSendsOwnerChunkPath() async throws {
        let captured = RequestCapture()
        let noteID = NoteFixtures.noteID
        let attachmentID = NoteFixtures.attachmentID
        let chunk = Data(repeating: 0xAB, count: 64)
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, chunk)
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        let data = try await client.readAttachmentChunk(
            noteID: noteID,
            attachmentID: attachmentID,
            chunkIndex: 0,
            accessToken: NoteFixtures.accessToken
        )

        XCTAssertEqual(captured.method, "GET")
        XCTAssertEqual(
            captured.path,
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())/chunks/0"
        )
        XCTAssertEqual(captured.authorization, "Bearer \(NoteFixtures.accessToken)")
        XCTAssertEqual(data, chunk)
    }

    func testReadSharedAttachmentChunkSendsSharedChunkPath() async throws {
        let captured = RequestCapture()
        let noteID = NoteFixtures.noteID
        let attachmentID = NoteFixtures.attachmentID
        let chunk = Data(repeating: 0xEF, count: 32)
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, chunk)
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        let data = try await client.readSharedAttachmentChunk(
            noteID: noteID,
            attachmentID: attachmentID,
            chunkIndex: 1,
            accessToken: NoteFixtures.accessToken
        )

        XCTAssertEqual(captured.method, "GET")
        XCTAssertEqual(
            captured.path,
            "/v1/notes/shared/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())/chunks/1"
        )
        XCTAssertEqual(captured.authorization, "Bearer \(NoteFixtures.accessToken)")
        XCTAssertEqual(data, chunk)
    }
}
