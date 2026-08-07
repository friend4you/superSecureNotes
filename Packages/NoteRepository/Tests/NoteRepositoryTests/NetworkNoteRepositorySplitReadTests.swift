import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol
import SecureCrypto

final class NetworkNoteRepositorySplitReadTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testReadNoteFetchesBodyOnlyAndLeavesAttachmentsEmpty() async throws {
        let log = RequestLog()
        let noteID = NoteFixtures.noteID
        let bodyPath = "/v1/notes/\(noteID.uuidString.lowercased())/body"
        let monolithicPath = "/v1/notes/\(noteID.uuidString.lowercased())"
        let attachmentsPath = "/v1/notes/\(noteID.uuidString.lowercased())/attachments"

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let path = request.url!.path
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(path, bodyPath)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.noteBytes)
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        let storedNote = try await repository.readNote(noteID: noteID)

        XCTAssertEqual(storedNote.metadata.noteID, noteID)
        XCTAssertEqual(storedNote.metadata.title, "My note")
        XCTAssertEqual(storedNote.syncState, .synced)
        XCTAssertTrue(storedNote.attachmentCiphertexts.isEmpty)
        XCTAssertEqual(log.count, 1)
        XCTAssertEqual(log.path(at: 0), bodyPath)
        XCTAssertFalse(log.paths.contains(monolithicPath))
        XCTAssertFalse(log.paths.contains(attachmentsPath))
        XCTAssertFalse(log.paths.contains { $0.contains("/attachments/") })
    }

    func testReadAttachmentFetchesCiphertextSeparately() async throws {
        let log = RequestLog()
        let noteID = NoteFixtures.noteID
        let attachmentID = NoteFixtures.attachmentID
        let ciphertext = Data(repeating: 0xEE, count: 64)
        let attachmentPath =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())"
        let bodyPath = "/v1/notes/\(noteID.uuidString.lowercased())/body"

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let path = request.url!.path
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(path, attachmentPath)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, ciphertext)
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        let data = try await repository.readAttachment(noteID: noteID, attachmentID: attachmentID)

        XCTAssertEqual(data, ciphertext)
        XCTAssertEqual(log.count, 1)
        XCTAssertEqual(log.path(at: 0), attachmentPath)
        XCTAssertFalse(log.paths.contains(bodyPath))
        XCTAssertFalse(log.paths.contains("/v1/notes/\(noteID.uuidString.lowercased())"))
    }

    func testReadNoteParsesSSNTBodySections() async throws {
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
        let expected = try parseNoteFile(NoteFixtures.noteBytes)

        XCTAssertEqual(storedNote.metadata, expected.metadata)
        XCTAssertEqual(storedNote.wrappedFEK, expected.wrappedFEK)
        XCTAssertEqual(storedNote.encryptedPayload, expected.encryptedPayload)
        XCTAssertEqual(storedNote.syncState, .synced)
        XCTAssertTrue(storedNote.attachmentCiphertexts.isEmpty)
    }
}
