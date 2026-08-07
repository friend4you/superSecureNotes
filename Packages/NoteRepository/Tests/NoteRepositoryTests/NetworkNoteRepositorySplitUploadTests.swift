import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol
import SecureCrypto

final class NetworkNoteRepositorySplitUploadTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testUploadNotePutsBodyThenEachAttachment() async throws {
        let log = RequestLog()
        let noteID = NoteFixtures.noteID
        let attachmentID1 = UUID(uuidString: "880E8400-E29B-41D4-A716-446655440010")!
        let attachmentID2 = UUID(uuidString: "880E8400-E29B-41D4-A716-446655440011")!
        let ciphertext1 = Data(repeating: 0x11, count: 32)
        let ciphertext2 = Data(repeating: 0x22, count: 48)
        let bodyPath = "/v1/notes/\(noteID.uuidString.lowercased())/body"
        let attachmentPath1 =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID1.uuidString.lowercased())"
        let attachmentPath2 =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID2.uuidString.lowercased())"
        let monolithicPath = "/v1/notes/\(noteID.uuidString.lowercased())"

        let note = StoredNote(
            metadata: NoteMetadata(
                noteID: noteID,
                title: "Split upload",
                createdAt: 1_700_000_000,
                updatedAt: 1_700_000_100,
                attachmentCount: 2,
                attachmentsTotalSize: UInt64(ciphertext1.count + ciphertext2.count)
            ),
            wrappedFEK: Data(repeating: 0xAB, count: 60),
            encryptedPayload: Data(repeating: 0xCD, count: 128),
            syncState: .pendingSync,
            attachmentCiphertexts: [
                attachmentID1: ciphertext1,
                attachmentID2: ciphertext2,
            ]
        )

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let path = request.url!.path
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)

            if path == bodyPath {
                XCTAssertEqual(request.httpMethod, "PUT")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/octet-stream")
                return (response, NoteFixtures.writeNoteResponseJSON(etag: #"W/"body-etag""#))
            }

            if path == "/v1/notes/\(noteID.uuidString.lowercased())/attachments" && request.httpMethod == "GET" {
                return (response, NoteFixtures.attachmentsManifestJSON(attachments: []))
            }

            if path == attachmentPath1 || path == attachmentPath2 {
                XCTAssertEqual(request.httpMethod, "PUT")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/octet-stream")
                return (response, NoteFixtures.writeAttachmentResponseJSON(noteEtag: #"W/"note-etag""#))
            }

            XCTFail("Unexpected path: \(path)")
            return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        let result = try await repository.uploadNote(note)

        XCTAssertEqual(result.syncState, .synced)
        XCTAssertEqual(log.method(at: 0), "PUT")
        XCTAssertEqual(log.path(at: 0), bodyPath)
        let bodySections = try parseNoteFile(try XCTUnwrap(log.bodyData(at: 0)))
        XCTAssertEqual(bodySections.metadata, note.metadata)
        XCTAssertEqual(bodySections.wrappedFEK, note.wrappedFEK)
        XCTAssertEqual(bodySections.encryptedPayload, note.encryptedPayload)

        let attachmentPaths = log.paths.filter { $0 == attachmentPath1 || $0 == attachmentPath2 }
        XCTAssertEqual(Set(attachmentPaths), Set([attachmentPath1, attachmentPath2]))
        XCTAssertEqual(log.count, 4)
        XCTAssertFalse(log.paths.contains(monolithicPath))
        XCTAssertFalse(log.paths.contains { $0.contains("/uploads") })

        let putBodies = zip(log.paths, (0..<log.count).map { log.bodyData(at: $0) })
            .filter { $0.0 == attachmentPath1 || $0.0 == attachmentPath2 }
        let bodiesByPath = Dictionary(uniqueKeysWithValues: putBodies)
        XCTAssertEqual(bodiesByPath[attachmentPath1], ciphertext1)
        XCTAssertEqual(bodiesByPath[attachmentPath2], ciphertext2)
    }

    func testUploadNoteUsesChunkedPathWhenAttachmentExceedsThreshold() async throws {
        let log = RequestLog()
        let noteID = NoteFixtures.noteID
        let attachmentID = NoteFixtures.attachmentID
        let uploadID = NoteFixtures.uploadID
        let chunkSize = 5_000_000
        let largeCiphertext = Data(repeating: 0xAA, count: NoteUploadSizeThreshold + 1)
        let bodyPath = "/v1/notes/\(noteID.uuidString.lowercased())/body"
        let directAttachmentPutPath =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())"
        let initPath =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())/uploads"
        let noteUploadsPath = "/v1/notes/\(noteID.uuidString.lowercased())/uploads"
        let monolithicPath = "/v1/notes/\(noteID.uuidString.lowercased())"

        let note = StoredNote(
            metadata: NoteMetadata(
                noteID: noteID,
                title: "Large attachment",
                createdAt: 1_700_000_000,
                updatedAt: 1_700_000_100,
                attachmentCount: 1,
                attachmentsTotalSize: UInt64(largeCiphertext.count)
            ),
            wrappedFEK: Data(repeating: 0xAB, count: 60),
            encryptedPayload: Data(repeating: 0xCD, count: 128),
            syncState: .pendingSync,
            attachmentCiphertexts: [attachmentID: largeCiphertext]
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
                XCTAssertEqual(totalSize, largeCiphertext.count)
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

        XCTAssertEqual(log.path(at: 0), bodyPath)
        XCTAssertEqual(log.method(at: 1), "POST")
        XCTAssertEqual(log.path(at: 1), initPath)
        XCTAssertTrue(log.paths.contains { $0.contains("/chunks/0") })
        XCTAssertTrue(log.paths.contains { $0.contains("/chunks/1") })
        XCTAssertTrue(log.paths.contains { $0.hasSuffix("/complete") })
        XCTAssertFalse(log.paths.contains(directAttachmentPutPath))
        XCTAssertFalse(log.paths.contains(noteUploadsPath))
        XCTAssertFalse(log.paths.contains(monolithicPath))
    }

    func testUploadNoteUsesSingleAttachmentPUTAtThreshold() async throws {
        let log = RequestLog()
        let noteID = NoteFixtures.noteID
        let attachmentID = NoteFixtures.attachmentID
        let ciphertext = Data(repeating: 0xBB, count: NoteUploadSizeThreshold)
        let bodyPath = "/v1/notes/\(noteID.uuidString.lowercased())/body"
        let attachmentPath =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())"

        let note = StoredNote(
            metadata: NoteMetadata(
                noteID: noteID,
                title: "Threshold attachment",
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
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            if path == bodyPath {
                return (response, NoteFixtures.writeNoteResponseJSON())
            }
            if path == "/v1/notes/\(noteID.uuidString.lowercased())/attachments" && request.httpMethod == "GET" {
                return (response, NoteFixtures.attachmentsManifestJSON(attachments: []))
            }
            if path == attachmentPath {
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

        XCTAssertEqual(log.path(at: 0), bodyPath)
        XCTAssertEqual(log.paths.filter { $0 == attachmentPath }.count, 1)
        XCTAssertEqual(log.bodyData(at: 1)?.count, NoteUploadSizeThreshold)
        XCTAssertFalse(log.paths.contains { $0.contains("/uploads") })
    }

    func testWriteNoteDoesNotUseMonolithicNotePUT() async throws {
        let log = RequestLog()
        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let path = request.url!.path
            if path.hasSuffix("/attachments") && request.httpMethod == "GET" {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, NoteFixtures.attachmentsManifestJSON(attachments: []))
            }
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.writeNoteResponseJSON())
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        try await repository.writeNote(NoteFixtures.sampleStoredNote)

        XCTAssertEqual(log.method(at: 0), "PUT")
        XCTAssertEqual(
            log.path(at: 0),
            "/v1/notes/\(NoteFixtures.noteID.uuidString.lowercased())/body"
        )
        XCTAssertFalse(log.paths.contains("/v1/notes/\(NoteFixtures.noteID.uuidString.lowercased())"))
    }
}
