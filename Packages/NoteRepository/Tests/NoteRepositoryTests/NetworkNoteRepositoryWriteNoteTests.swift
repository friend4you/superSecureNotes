import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class NetworkNoteRepositoryWriteNoteTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testWriteNoteSucceedsOn200WithUploadResponse() async throws {
        URLProtocolStub.requestHandler = { request in
            let path = request.url!.path
            if path.hasSuffix("/attachments") && request.httpMethod == "GET" {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, NoteFixtures.attachmentsManifestJSON())
            }
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (
                response,
                NoteFixtures.writeNoteResponseJSON(
                    syncState: "synced",
                    updatedAt: 1_800_000_000,
                    etag: #"W/"repo-etag""#
                )
            )
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        let result = try await repository.uploadNote(NoteFixtures.sampleStoredNote)

        XCTAssertEqual(result.syncState, .synced)
        XCTAssertEqual(result.updatedAt, 1_800_000_000)
        XCTAssertEqual(result.etag, #"W/"repo-etag""#)
    }

    func testWriteNoteSucceedsOnNoContent() async throws {
        URLProtocolStub.requestHandler = { request in
            let path = request.url!.path
            if path.hasSuffix("/attachments") && request.httpMethod == "GET" {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, NoteFixtures.attachmentsManifestJSON())
            }
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 204)
            return (response, nil)
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        try await repository.writeNote(NoteFixtures.sampleStoredNote)
    }

    func testWriteNoteRejectsEmptyDataLocally() async {
        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        let emptyNote = StoredNote(
            metadata: NoteFixtures.sampleStoredNote.metadata,
            wrappedFEK: NoteFixtures.sampleStoredNote.wrappedFEK,
            encryptedPayload: Data(),
            syncState: .pendingSync
        )

        do {
            try await repository.writeNote(emptyNote)
            XCTFail("Expected validationError")
        } catch let error as NoteRepositoryError {
            XCTAssertEqual(error, .validationError("Note must not be empty."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testWriteNoteMapsValidationError() async {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 400)
            return (response, NoteFixtures.errorJSON(error: "validation_error", message: "Invalid note."))
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        do {
            try await repository.writeNote(NoteFixtures.sampleStoredNote)
            XCTFail("Expected validationError")
        } catch let error as NoteRepositoryError {
            XCTAssertEqual(error, .validationError("Invalid note."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUploadNoteUsesSinglePUTForSubThresholdBlob() async throws {
        let log = RequestLog()
        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let path = request.url!.path
            if path.hasSuffix("/attachments") && request.httpMethod == "GET" {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, NoteFixtures.attachmentsManifestJSON())
            }
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.writeNoteResponseJSON())
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        _ = try await repository.uploadNote(NoteFixtures.sampleStoredNote)

        XCTAssertEqual(log.method(at: 0), "GET")
        XCTAssertEqual(log.method(at: 1), "GET")
        XCTAssertEqual(log.path(at: 2), "/v1/notes/\(NoteFixtures.noteID.uuidString.lowercased())/body")
        XCTAssertFalse(log.paths.contains { $0.contains("/uploads") })
    }

    func testUploadNoteUsesSingleBodyPUTAtThresholdWireBlobSize() async throws {
        let log = RequestLog()
        let note = try NoteTestSupport.makeStoredNoteWithWireBlobSize(
            noteID: NoteFixtures.noteID,
            title: "Threshold note",
            wireBlobSize: NoteUploadSizeThreshold
        )
        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let path = request.url!.path
            if path.hasSuffix("/attachments") && request.httpMethod == "GET" {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, NoteFixtures.attachmentsManifestJSON())
            }
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.writeNoteResponseJSON())
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        _ = try await repository.uploadNote(note)

        XCTAssertEqual(log.method(at: 0), "GET")
        XCTAssertEqual(log.method(at: 1), "GET")
        XCTAssertEqual(log.path(at: 2), "/v1/notes/\(NoteFixtures.noteID.uuidString.lowercased())/body")
        XCTAssertFalse(log.paths.contains { $0.contains("/uploads") })
        let bodyIndex = try XCTUnwrap(log.paths.firstIndex {
            $0 == "/v1/notes/\(NoteFixtures.noteID.uuidString.lowercased())/body"
        })
        XCTAssertEqual(log.bodyData(at: bodyIndex)?.count, NoteUploadSizeThreshold)
    }

    func testWriteNotePropagatesTokenProviderFailure() async {
        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(error: MockTokenProvider.Failure.missingToken),
            session: .stubbed()
        )

        do {
            try await repository.writeNote(NoteFixtures.sampleStoredNote)
            XCTFail("Expected token provider error")
        } catch is MockTokenProvider.Failure {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
