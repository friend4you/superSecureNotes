import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class NetworkNoteRepositoryReadNoteTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testReadNoteReturnsBodyOnSuccess() async throws {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.noteBytes)
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        let noteData = try await repository.readNote(noteID: NoteFixtures.noteID)
        XCTAssertEqual(noteData, NoteFixtures.noteBytes)
    }

    func testReadNoteMapsNoteNotFound() async {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 404)
            return (response, NoteFixtures.errorJSON(error: "note_not_found", message: "No note."))
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        do {
            _ = try await repository.readNote(noteID: NoteFixtures.noteID)
            XCTFail("Expected noteNotFound")
        } catch let error as NoteRepositoryError {
            XCTAssertEqual(error, .noteNotFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testReadNotePropagatesTokenProviderFailure() async {
        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(error: MockTokenProvider.Failure.missingToken),
            session: .stubbed()
        )

        do {
            _ = try await repository.readNote(noteID: NoteFixtures.noteID)
            XCTFail("Expected token provider error")
        } catch is MockTokenProvider.Failure {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
