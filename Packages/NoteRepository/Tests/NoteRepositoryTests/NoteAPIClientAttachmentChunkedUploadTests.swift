import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class NoteAPIClientAttachmentChunkedUploadTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testInitAttachmentUploadPostsTotalSize() async throws {
        let log = RequestLog()
        let noteID = NoteFixtures.noteID
        let attachmentID = NoteFixtures.attachmentID
        let totalSize = 12
        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (
                response,
                NoteFixtures.uploadInitResponseJSON(
                    uploadId: NoteFixtures.uploadID,
                    chunkSize: 4,
                    totalChunks: 3
                )
            )
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        let session = try await client.initAttachmentUpload(
            noteID: noteID,
            attachmentID: attachmentID,
            totalSize: totalSize,
            accessToken: NoteFixtures.accessToken
        )

        XCTAssertEqual(session.uploadID, NoteFixtures.uploadID)
        XCTAssertEqual(session.chunkSize, 4)
        XCTAssertEqual(session.totalChunks, 3)
        XCTAssertEqual(log.method(at: 0), "POST")
        XCTAssertEqual(
            log.path(at: 0),
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())/uploads"
        )
        let initBody = try XCTUnwrap(log.jsonObject(at: 0) as? [String: Any])
        XCTAssertEqual(initBody["totalSize"] as? Int, totalSize)
        XCTAssertEqual(initBody["contentType"] as? String, "application/octet-stream")
    }

    func testInitAttachmentUploadAcceptsCreatedStatus() async throws {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 201)
            return (
                response,
                NoteFixtures.uploadInitResponseJSON(
                    uploadId: NoteFixtures.uploadID,
                    chunkSize: 5_242_880,
                    totalChunks: 3
                )
            )
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        let session = try await client.initAttachmentUpload(
            noteID: NoteFixtures.noteID,
            attachmentID: NoteFixtures.attachmentID,
            totalSize: 11_000_000,
            accessToken: NoteFixtures.accessToken
        )

        XCTAssertEqual(session.uploadID, NoteFixtures.uploadID)
    }

    func testAttachmentChunkedUploadFlowUploadsAllChunksThenCompletes() async throws {
        let log = RequestLog()
        let noteID = NoteFixtures.noteID
        let attachmentID = NoteFixtures.attachmentID
        let uploadID = NoteFixtures.uploadID
        let wireBlob = Data((0..<12).map { UInt8($0) })
        let chunkSize = 4
        let totalChunks = 3
        let initPath =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())/uploads"

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let path = request.url!.path

            if path == initPath {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (
                    response,
                    NoteFixtures.uploadInitResponseJSON(
                        uploadId: uploadID,
                        chunkSize: chunkSize,
                        totalChunks: totalChunks
                    )
                )
            }

            if path.contains("/chunks/") {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 204)
                return (response, nil)
            }

            if path.hasSuffix("/complete") {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (
                    response,
                    NoteFixtures.writeAttachmentResponseJSON(
                        etag: #"W/"chunked-att-etag""#,
                        noteEtag: #"W/"chunked-note-etag""#
                    )
                )
            }

            XCTFail("Unexpected path: \(path)")
            return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        let session = try await client.initAttachmentUpload(
            noteID: noteID,
            attachmentID: attachmentID,
            totalSize: wireBlob.count,
            accessToken: NoteFixtures.accessToken
        )

        for chunkIndex in 0..<session.totalChunks {
            let start = chunkIndex * session.chunkSize
            let end = min(start + session.chunkSize, wireBlob.count)
            try await client.uploadAttachmentChunk(
                noteID: noteID,
                attachmentID: attachmentID,
                uploadID: session.uploadID,
                chunkIndex: chunkIndex,
                data: wireBlob.subdata(in: start..<end),
                accessToken: NoteFixtures.accessToken
            )
        }

        let result = try await client.completeAttachmentUpload(
            noteID: noteID,
            attachmentID: attachmentID,
            uploadID: session.uploadID,
            accessToken: NoteFixtures.accessToken,
            ifMatch: #"W/"local-att-etag""#
        )

        XCTAssertEqual(result.etag, #"W/"chunked-att-etag""#)
        XCTAssertEqual(result.noteEtag, #"W/"chunked-note-etag""#)
        XCTAssertEqual(log.count, 5)
        XCTAssertEqual(log.bodyData(at: 1)?.count, chunkSize)

        for chunkIndex in 0..<totalChunks {
            let expectedPath =
                "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())/uploads/\(uploadID.uuidString.lowercased())/chunks/\(chunkIndex)"
            XCTAssertEqual(log.path(at: chunkIndex + 1), expectedPath)
            XCTAssertEqual(log.method(at: chunkIndex + 1), "PUT")
            let start = chunkIndex * chunkSize
            let end = min(start + chunkSize, wireBlob.count)
            XCTAssertEqual(log.bodyData(at: chunkIndex + 1), wireBlob.subdata(in: start..<end))
        }

        let completeBody = try XCTUnwrap(log.jsonObject(at: 4) as? [String: Any])
        XCTAssertEqual(completeBody["ifMatch"] as? String, #"W/"local-att-etag""#)
    }

    func testCompleteAttachmentUploadOmitsIfMatchWhenNotProvided() async throws {
        let log = RequestLog()
        let noteID = NoteFixtures.noteID
        let attachmentID = NoteFixtures.attachmentID
        let uploadID = NoteFixtures.uploadID
        let completePath =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())/uploads/\(uploadID.uuidString.lowercased())/complete"

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.writeAttachmentResponseJSON())
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        _ = try await client.completeAttachmentUpload(
            noteID: noteID,
            attachmentID: attachmentID,
            uploadID: uploadID,
            accessToken: NoteFixtures.accessToken
        )

        XCTAssertEqual(log.path(at: 0), completePath)
        let completeBody = try XCTUnwrap(log.jsonObject(at: 0) as? [String: Any])
        XCTAssertNil(completeBody["ifMatch"])
    }

    func testUploadAttachmentChunkUsesOctetStream() async throws {
        let captured = RequestCapture()
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 204)
            return (response, nil)
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        try await client.uploadAttachmentChunk(
            noteID: NoteFixtures.noteID,
            attachmentID: NoteFixtures.attachmentID,
            uploadID: NoteFixtures.uploadID,
            chunkIndex: 0,
            data: Data([0x01, 0x02, 0x03]),
            accessToken: NoteFixtures.accessToken
        )

        XCTAssertEqual(captured.contentType, "application/octet-stream")
    }
}
