import SecureCrypto
import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class NetworkNoteRepositorySharedBodyTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testReadSharedBodyFetchesRawBytesFromSplitEndpoint() async throws {
        let captured = RequestCapture()
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.noteBytes)
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        let bodyData = try await repository.readSharedBody(noteID: NoteFixtures.noteID)

        XCTAssertEqual(captured.method, "GET")
        XCTAssertEqual(
            captured.path,
            "/v1/notes/shared/\(NoteFixtures.noteID.uuidString.lowercased())/body"
        )
        XCTAssertEqual(bodyData, NoteFixtures.noteBytes)
    }

    func testImportSharedBodyUsesJSONDownloadWithRecipientWrappedFEK() async throws {
        let captured = RequestCapture()
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.readSharedNoteJSON())
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        let imported = try await repository.importSharedBody(noteID: NoteFixtures.noteID)

        XCTAssertEqual(
            captured.path,
            "/v1/notes/shared/\(NoteFixtures.noteID.uuidString.lowercased())"
        )
        XCTAssertEqual(imported.bodyData, NoteFixtures.noteBytes)
        XCTAssertEqual(imported.note.recipientWrappedFEK, NoteFixtures.recipientWrappedFEK)
        XCTAssertNotEqual(imported.note.recipientWrappedFEK, try parseNoteFile(NoteFixtures.noteBytes).wrappedFEK)
    }
}
