import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class NetworkNoteRepositoryChunkDownloadTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testReadAttachmentConcatenatesOwnerChunks() async throws {
        let log = RequestLog()
        let noteID = NoteFixtures.noteID
        let attachmentID = NoteFixtures.attachmentID
        let chunk0 = Data(repeating: 0x01, count: 4)
        let chunk1 = Data(repeating: 0x02, count: 4)
        let ciphertext = chunk0 + chunk1
        let summary = RemoteAttachmentSummary(
            attachmentID: attachmentID,
            sizeBytes: UInt64(ciphertext.count),
            contentType: "application/octet-stream",
            etag: #"W/"att""#,
            totalChunks: 2,
            chunkSize: 4
        )
        let chunk0Path =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())/chunks/0"
        let chunk1Path =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())/chunks/1"
        let blobPath =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())"

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let path = request.url!.path
            XCTAssertEqual(request.httpMethod, "GET")
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            if path == chunk0Path {
                return (response, chunk0)
            }
            if path == chunk1Path {
                return (response, chunk1)
            }
            XCTFail("Unexpected path: \(path)")
            return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        let data = try await repository.readAttachment(
            noteID: noteID,
            summary: summary,
            onBytesReceived: nil
        )

        XCTAssertEqual(data, ciphertext)
        XCTAssertEqual(log.paths, [chunk0Path, chunk1Path])
        XCTAssertFalse(log.paths.contains(blobPath))
    }

    func testReadSharedAttachmentConcatenatesSharedChunks() async throws {
        let log = RequestLog()
        let noteID = NoteFixtures.noteID
        let attachmentID = NoteFixtures.attachmentID
        let chunk0 = Data(repeating: 0x11, count: 3)
        let chunk1 = Data(repeating: 0x22, count: 3)
        let ciphertext = chunk0 + chunk1
        let summary = RemoteAttachmentSummary(
            attachmentID: attachmentID,
            sizeBytes: UInt64(ciphertext.count),
            contentType: "application/octet-stream",
            etag: #"W/"shared""#,
            totalChunks: 2,
            chunkSize: 3
        )
        let chunk0Path =
            "/v1/notes/shared/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())/chunks/0"
        let chunk1Path =
            "/v1/notes/shared/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())/chunks/1"
        let ownerBlobPath =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())"

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let path = request.url!.path
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            if path == chunk0Path {
                return (response, chunk0)
            }
            if path == chunk1Path {
                return (response, chunk1)
            }
            XCTFail("Unexpected path: \(path)")
            return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        let data = try await repository.readSharedAttachment(
            noteID: noteID,
            summary: summary,
            onBytesReceived: nil
        )

        XCTAssertEqual(data, ciphertext)
        XCTAssertEqual(log.paths, [chunk0Path, chunk1Path])
        XCTAssertFalse(log.paths.contains(ownerBlobPath))
    }

    func testReadAttachmentByIDFetchesManifestThenChunks() async throws {
        let log = RequestLog()
        let noteID = NoteFixtures.noteID
        let attachmentID = NoteFixtures.attachmentID
        let ciphertext = Data(repeating: 0xEE, count: 8)
        let manifestPath = "/v1/notes/\(noteID.uuidString.lowercased())/attachments"
        let chunkPath =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())/chunks/0"

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let path = request.url!.path
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            if path == manifestPath && request.httpMethod == "GET" {
                return (
                    response,
                    NoteFixtures.attachmentsManifestJSON(attachments: [
                        (
                            attachmentID: attachmentID,
                            sizeBytes: UInt64(ciphertext.count),
                            contentType: "application/octet-stream",
                            etag: #"W/"a""#,
                            totalChunks: 1,
                            chunkSize: ciphertext.count
                        ),
                    ])
                )
            }
            if path == chunkPath {
                return (response, ciphertext)
            }
            XCTFail("Unexpected path: \(path)")
            return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        let data = try await repository.readAttachment(noteID: noteID, attachmentID: attachmentID)

        XCTAssertEqual(data, ciphertext)
        XCTAssertEqual(log.path(at: 0), manifestPath)
        XCTAssertEqual(log.path(at: 1), chunkPath)
    }
}
