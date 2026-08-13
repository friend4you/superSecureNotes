import SecureCrypto
import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class NetworkNoteRepositorySharedBodyTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testReadSharedBodyParsesSplitEndpoint() async throws {
        let captured = RequestCapture()
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.readSharedBodyJSON())
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        let shared = try await repository.readSharedBody(noteID: NoteFixtures.noteID)
        let sections = try parseNoteFile(NoteFixtures.noteBytes)

        XCTAssertEqual(captured.method, "GET")
        XCTAssertEqual(
            captured.path,
            "/v1/notes/shared/\(NoteFixtures.noteID.uuidString.lowercased())/body"
        )
        XCTAssertEqual(shared.noteID, NoteFixtures.noteID)
        XCTAssertEqual(shared.metadata, sections.metadata)
        XCTAssertEqual(shared.recipientWrappedFEK, NoteFixtures.recipientWrappedFEK)
        XCTAssertEqual(shared.encryptedPayload, sections.encryptedPayload)
    }

    func testReadSharedBodyDoesNotCallMonolithicBlobEndpoint() async throws {
        let log = RequestLog()
        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.readSharedBodyJSON())
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        _ = try await repository.readSharedBody(noteID: NoteFixtures.noteID)

        let monolithicPath = "/v1/notes/shared/\(NoteFixtures.noteID.uuidString.lowercased())"
        XCTAssertFalse(log.paths.contains(monolithicPath))
    }
}
