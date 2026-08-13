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

        try await repository.writeNote(NoteFixtures.sampleStoredNote)

        let bodyPath = "/v1/notes/\(NoteFixtures.noteID.uuidString.lowercased())/body"
        let bodyIndex = try XCTUnwrap(log.paths.firstIndex(of: bodyPath))
        let body = try XCTUnwrap(log.bodyData(at: bodyIndex))
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
