import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class NetworkNoteRepositoryErrorTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testTransportFailureMapsToNetworkError() async {
        URLProtocolStub.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        do {
            _ = try await repository.readNote(noteID: NoteFixtures.noteID)
            XCTFail("Expected networkError")
        } catch let error as NoteRepositoryError {
            XCTAssertEqual(error, .networkError)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUnhandledStatusMapsToServerError() async {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 500)
            return (response, Data())
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        do {
            _ = try await repository.readNote(noteID: NoteFixtures.noteID)
            XCTFail("Expected serverError")
        } catch let error as NoteRepositoryError {
            XCTAssertEqual(error, .serverError(statusCode: 500, message: nil))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
