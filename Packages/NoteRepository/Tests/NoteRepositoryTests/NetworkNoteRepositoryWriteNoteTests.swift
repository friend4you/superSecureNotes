import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class NetworkNoteRepositoryWriteNoteTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testWriteNoteSucceedsOnNoContent() async throws {
        URLProtocolStub.requestHandler = { request in
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
