import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol
import SecureCrypto

final class NetworkNoteRepositoryStoredNoteTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testWriteAssemblesWireBlob() async throws {
        let captured = RequestCapture()
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.writeNoteResponseJSON())
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        try await repository.writeNote(NoteFixtures.sampleStoredNote)

        let body = try XCTUnwrap(captured.bodyData)
        let sections = try parseNoteFile(body)
        XCTAssertEqual(sections.metadata, NoteFixtures.sampleStoredNote.metadata)
        XCTAssertEqual(sections.wrappedFEK, NoteFixtures.sampleStoredNote.wrappedFEK)
        XCTAssertEqual(sections.encryptedPayload, NoteFixtures.sampleStoredNote.encryptedPayload)
    }

    func testReadParsesStoredNoteWithSyncedState() async throws {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.noteBytes)
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        let storedNote = try await repository.readNote(noteID: NoteFixtures.noteID)

        XCTAssertEqual(storedNote.metadata.noteID, NoteFixtures.noteID)
        XCTAssertEqual(storedNote.syncState, .synced)
    }
}
