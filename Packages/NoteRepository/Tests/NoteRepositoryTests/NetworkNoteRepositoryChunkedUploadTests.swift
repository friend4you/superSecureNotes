import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class NetworkNoteRepositoryChunkedUploadTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testUploadNoteUsesChunkedFlowForOverThresholdBlob() async throws {
        let log = RequestLog()
        let noteID = NoteFixtures.noteID
        let uploadID = NoteFixtures.uploadID
        let chunkSize = 5_000_000
        let note = try NoteTestSupport.makeStoredNoteWithWireBlobSize(
            noteID: noteID,
            title: "Large note",
            wireBlobSize: NoteUploadSizeThreshold + 1
        )
        let initPath = "/v1/notes/\(noteID.uuidString.lowercased())/uploads"
        let directPutPath = "/v1/notes/\(noteID.uuidString.lowercased())"

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let path = request.url!.path

            if path == initPath {
                guard
                    let bodyData = TestHTTP.bodyData(from: request),
                    let body = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
                    let totalSize = body["totalSize"] as? Int
                else {
                    XCTFail("Missing init request body")
                    return (TestHTTP.makeResponse(url: request.url!, statusCode: 400), Data())
                }
                let totalChunks = (totalSize + chunkSize - 1) / chunkSize
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
                return (response, NoteFixtures.writeNoteResponseJSON())
            }

            XCTFail("Unexpected path: \(path)")
            return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        _ = try await repository.uploadNote(note)

        XCTAssertFalse(log.paths.contains(directPutPath))
        XCTAssertEqual(log.method(at: 0), "POST")
        XCTAssertEqual(log.path(at: 0), initPath)
        XCTAssertTrue(log.paths.contains { $0.contains("/chunks/0") })
        XCTAssertTrue(log.paths.contains { $0.contains("/chunks/1") })
        XCTAssertTrue(log.paths.contains { $0.hasSuffix("/complete") })
    }

    func testFailedChunkIsRetriedWithoutResendingPriorChunks() async throws {
        let log = RequestLog()
        let noteID = NoteFixtures.noteID
        let uploadID = NoteFixtures.uploadID
        let chunkSize = 5_000_000
        var chunkAttempts: [Int: Int] = [:]
        let note = try NoteTestSupport.makeStoredNoteWithWireBlobSize(
            noteID: noteID,
            title: "Large note",
            wireBlobSize: NoteUploadSizeThreshold + 1
        )
        let initPath = "/v1/notes/\(noteID.uuidString.lowercased())/uploads"

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let path = request.url!.path

            if path == initPath {
                guard
                    let bodyData = TestHTTP.bodyData(from: request),
                    let body = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
                    let totalSize = body["totalSize"] as? Int
                else {
                    XCTFail("Missing init request body")
                    return (TestHTTP.makeResponse(url: request.url!, statusCode: 400), Data())
                }
                let totalChunks = (totalSize + chunkSize - 1) / chunkSize
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
                guard let chunkIndex = Int(path.split(separator: "/").last ?? "") else {
                    XCTFail("Missing chunk index in path: \(path)")
                    return (TestHTTP.makeResponse(url: request.url!, statusCode: 400), Data())
                }
                chunkAttempts[chunkIndex, default: 0] += 1
                if chunkIndex == 1 && chunkAttempts[chunkIndex] == 1 {
                    throw URLError(.networkConnectionLost)
                }
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 204)
                return (response, nil)
            }

            if path.hasSuffix("/complete") {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, NoteFixtures.writeNoteResponseJSON())
            }

            XCTFail("Unexpected path: \(path)")
            return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        _ = try await repository.uploadNote(note)

        XCTAssertEqual(chunkAttempts[0], 1)
        XCTAssertEqual(chunkAttempts[1], 2)
        XCTAssertEqual(chunkAttempts[2], 1)
        XCTAssertEqual(log.paths.filter { $0.contains("/chunks/0") }.count, 1)
        XCTAssertEqual(log.paths.filter { $0.contains("/chunks/1") }.count, 2)
        XCTAssertEqual(log.paths.filter { $0.contains("/chunks/2") }.count, 1)
    }
}
