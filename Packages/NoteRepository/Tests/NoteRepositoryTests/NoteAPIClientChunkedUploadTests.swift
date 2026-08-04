import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class NoteAPIClientChunkedUploadTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testInitUploadPostsTotalSize() async throws {
        let log = RequestLog()
        let noteID = NoteFixtures.noteID
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
        let session = try await client.initUpload(
            noteID: noteID,
            totalSize: totalSize,
            accessToken: NoteFixtures.accessToken
        )

        XCTAssertEqual(session.uploadID, NoteFixtures.uploadID)
        XCTAssertEqual(session.chunkSize, 4)
        XCTAssertEqual(session.totalChunks, 3)
        XCTAssertEqual(log.method(at: 0), "POST")
        XCTAssertEqual(log.path(at: 0), "/v1/notes/\(noteID.uuidString.lowercased())/uploads")
        let initBody = try XCTUnwrap(log.jsonObject(at: 0) as? [String: Any])
        XCTAssertEqual(initBody["totalSize"] as? Int, totalSize)
    }

    func testChunkedUploadFlowUploadsAllChunksThenCompletes() async throws {
        let log = RequestLog()
        let noteID = NoteFixtures.noteID
        let uploadID = NoteFixtures.uploadID
        let wireBlob = Data((0..<12).map { UInt8($0) })
        let chunkSize = 4
        let totalChunks = 3
        let initPath = "/v1/notes/\(noteID.uuidString.lowercased())/uploads"

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
                    NoteFixtures.writeNoteResponseJSON(
                        syncState: "synced",
                        updatedAt: 1_800_000_000,
                        etag: #"W/"chunked-etag""#
                    )
                )
            }

            XCTFail("Unexpected path: \(path)")
            return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        let session = try await client.initUpload(
            noteID: noteID,
            totalSize: wireBlob.count,
            accessToken: NoteFixtures.accessToken
        )

        for chunkIndex in 0..<session.totalChunks {
            let start = chunkIndex * session.chunkSize
            let end = min(start + session.chunkSize, wireBlob.count)
            try await client.uploadChunk(
                noteID: noteID,
                uploadID: session.uploadID,
                chunkIndex: chunkIndex,
                data: wireBlob.subdata(in: start..<end),
                accessToken: NoteFixtures.accessToken
            )
        }

        let result = try await client.completeUpload(
            noteID: noteID,
            uploadID: session.uploadID,
            accessToken: NoteFixtures.accessToken,
            ifMatch: #"W/"local-etag""#
        )

        XCTAssertEqual(result.syncState, .synced)
        XCTAssertEqual(result.updatedAt, 1_800_000_000)
        XCTAssertEqual(result.etag, #"W/"chunked-etag""#)
        XCTAssertEqual(log.count, 5)
        XCTAssertFalse(log.paths.contains("/v1/notes/\(noteID.uuidString.lowercased())"))

        for chunkIndex in 0..<totalChunks {
            let expectedPath =
                "/v1/notes/\(noteID.uuidString.lowercased())/uploads/\(uploadID.uuidString.lowercased())/chunks/\(chunkIndex)"
            XCTAssertEqual(log.path(at: chunkIndex + 1), expectedPath)
            let start = chunkIndex * chunkSize
            let end = min(start + chunkSize, wireBlob.count)
            XCTAssertEqual(log.bodyData(at: chunkIndex + 1), wireBlob.subdata(in: start..<end))
        }

        let completeBody = try XCTUnwrap(log.jsonObject(at: 4) as? [String: Any])
        XCTAssertEqual(completeBody["ifMatch"] as? String, #"W/"local-etag""#)
    }

    func testCompleteUploadOmitsIfMatchWhenNotProvided() async throws {
        let log = RequestLog()
        let noteID = NoteFixtures.noteID
        let uploadID = NoteFixtures.uploadID
        let completePath =
            "/v1/notes/\(noteID.uuidString.lowercased())/uploads/\(uploadID.uuidString.lowercased())/complete"

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.writeNoteResponseJSON())
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        _ = try await client.completeUpload(
            noteID: noteID,
            uploadID: uploadID,
            accessToken: NoteFixtures.accessToken
        )

        XCTAssertEqual(log.path(at: 0), completePath)
        let completeBody = try XCTUnwrap(log.jsonObject(at: 0) as? [String: Any])
        XCTAssertNil(completeBody["ifMatch"])
    }
}
