import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol
import SecureCrypto

final class NetworkNoteRepositoryChunkedUploadTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testUploadNoteUsesChunkedFlowForOverThresholdAttachment() async throws {
        let log = RequestLog()
        let noteID = NoteFixtures.noteID
        let attachmentID = NoteFixtures.attachmentID
        let uploadID = NoteFixtures.uploadID
        let chunkSize = 5_000_000
        let ciphertext = Data(repeating: 0xAA, count: NoteUploadSizeThreshold + 1)
        let bodyPath = "/v1/notes/\(noteID.uuidString.lowercased())/body"
        let initPath =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())/uploads"
        let directAttachmentPutPath =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())"
        let noteUploadsPath = "/v1/notes/\(noteID.uuidString.lowercased())/uploads"

        let note = StoredNote(
            metadata: NoteMetadata(
                noteID: noteID,
                title: "Large attachment",
                createdAt: 1_700_000_000,
                updatedAt: 1_700_000_100,
                attachmentCount: 1,
                attachmentsTotalSize: UInt64(ciphertext.count)
            ),
            wrappedFEK: Data(repeating: 0xAB, count: 60),
            encryptedPayload: Data(repeating: 0xCD, count: 128),
            syncState: .pendingSync,
            attachmentCiphertexts: [attachmentID: ciphertext]
        )

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let path = request.url!.path

            if path == bodyPath {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, NoteFixtures.writeNoteResponseJSON())
            }

            if path == "/v1/notes/\(noteID.uuidString.lowercased())/attachments" && request.httpMethod == "GET" {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, NoteFixtures.attachmentsManifestJSON(attachments: []))
            }

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
                return (response, NoteFixtures.writeAttachmentResponseJSON())
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

        XCTAssertFalse(log.paths.contains(directAttachmentPutPath))
        XCTAssertFalse(log.paths.contains(noteUploadsPath))
        XCTAssertEqual(log.method(at: 0), "PUT")
        XCTAssertEqual(log.path(at: 0), bodyPath)
        XCTAssertEqual(log.method(at: 1), "POST")
        XCTAssertEqual(log.path(at: 1), initPath)
        XCTAssertTrue(log.paths.contains { $0.contains("/chunks/0") })
        XCTAssertTrue(log.paths.contains { $0.contains("/chunks/1") })
        XCTAssertTrue(log.paths.contains { $0.hasSuffix("/complete") })
    }

    func testFailedAttachmentChunkIsRetriedWithoutResendingPriorChunks() async throws {
        let log = RequestLog()
        let noteID = NoteFixtures.noteID
        let attachmentID = NoteFixtures.attachmentID
        let uploadID = NoteFixtures.uploadID
        let chunkSize = 5_000_000
        var chunkAttempts: [Int: Int] = [:]
        let ciphertext = Data(repeating: 0xAA, count: NoteUploadSizeThreshold + 1)
        let bodyPath = "/v1/notes/\(noteID.uuidString.lowercased())/body"
        let initPath =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())/uploads"

        let note = StoredNote(
            metadata: NoteMetadata(
                noteID: noteID,
                title: "Large attachment",
                createdAt: 1_700_000_000,
                updatedAt: 1_700_000_100,
                attachmentCount: 1,
                attachmentsTotalSize: UInt64(ciphertext.count)
            ),
            wrappedFEK: Data(repeating: 0xAB, count: 60),
            encryptedPayload: Data(repeating: 0xCD, count: 128),
            syncState: .pendingSync,
            attachmentCiphertexts: [attachmentID: ciphertext]
        )

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let path = request.url!.path

            if path == bodyPath {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, NoteFixtures.writeNoteResponseJSON())
            }

            if path == "/v1/notes/\(noteID.uuidString.lowercased())/attachments" && request.httpMethod == "GET" {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, NoteFixtures.attachmentsManifestJSON(attachments: []))
            }

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
                return (response, NoteFixtures.writeAttachmentResponseJSON())
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
