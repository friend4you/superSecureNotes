import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class NetworkNoteRepositoryListNotesTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testListNotesReturnsSummariesOnSuccess() async throws {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.listNotesJSON())
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        let notes = try await repository.listNotes()
        XCTAssertEqual(notes, [NoteFixtures.sampleSummary])
    }

    func testListNotesReturnsEmptyArray() async throws {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.listNotesJSON(summaries: []))
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        let notes = try await repository.listNotes()
        XCTAssertTrue(notes.isEmpty)
    }

    func testListNotesPropagatesTokenProviderFailure() async {
        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(error: MockTokenProvider.Failure.missingToken),
            session: .stubbed()
        )

        do {
            _ = try await repository.listNotes()
            XCTFail("Expected token provider error")
        } catch is MockTokenProvider.Failure {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
