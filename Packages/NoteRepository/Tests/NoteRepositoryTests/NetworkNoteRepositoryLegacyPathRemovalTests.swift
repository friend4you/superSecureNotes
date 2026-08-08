import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol
import SecureCrypto

final class NetworkNoteRepositoryLegacyPathRemovalTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testReadNoteDoesNotCallMonolithicNoteEndpoint() async throws {
        let log = RequestLog()
        let noteID = NoteFixtures.noteID
        let monolithicPath = "/v1/notes/\(noteID.uuidString.lowercased())"
        let bodyPath = "\(monolithicPath)/body"

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.noteBytes)
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        _ = try await repository.readNote(noteID: noteID)

        XCTAssertTrue(log.paths.contains(bodyPath))
        XCTAssertFalse(log.paths.contains(monolithicPath))
        XCTAssertFalse(log.paths.contains { $0.hasSuffix("/uploads") })
    }

    func testUploadNoteDoesNotCallMonolithicNoteEndpoint() async throws {
        let log = RequestLog()
        let noteID = NoteFixtures.noteID
        let attachmentID = NoteFixtures.attachmentID
        let monolithicPath = "/v1/notes/\(noteID.uuidString.lowercased())"
        let bodyPath = "\(monolithicPath)/body"
        let noteUploadsPath = "\(monolithicPath)/uploads"
        let attachmentPath = "\(monolithicPath)/attachments/\(attachmentID.uuidString.lowercased())"

        let note = StoredNote(
            metadata: NoteMetadata(
                noteID: noteID,
                title: "Legacy removal",
                createdAt: 1_700_000_000,
                updatedAt: 1_700_000_100,
                attachmentCount: 1,
                attachmentsTotalSize: 16
            ),
            wrappedFEK: Data(repeating: 0xAB, count: 60),
            encryptedPayload: Data(repeating: 0xCD, count: 128),
            syncState: .pendingSync,
            attachmentCiphertexts: [attachmentID: Data(repeating: 0xEE, count: 16)]
        )

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let path = request.url!.path
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)

            if path == bodyPath {
                return (response, NoteFixtures.writeNoteResponseJSON())
            }
            if path == "\(monolithicPath)/attachments" && request.httpMethod == "GET" {
                return (response, NoteFixtures.attachmentsManifestJSON(attachments: []))
            }
            if path == attachmentPath {
                return (response, NoteFixtures.writeAttachmentResponseJSON())
            }

            XCTFail("Unexpected path: \(path)")
            return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        _ = try await repository.uploadNote(note)

        XCTAssertTrue(log.paths.contains(bodyPath))
        XCTAssertTrue(log.paths.contains(attachmentPath))
        XCTAssertFalse(log.paths.contains(monolithicPath))
        XCTAssertFalse(log.paths.contains(noteUploadsPath))
    }
}

final class NoteAPIClientLegacyPathRemovalTests: XCTestCase {
    func testMonolithicReadNoteIsUnsupported() async throws {
        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())

        do {
            _ = try await client.readNote(noteID: NoteFixtures.noteID, accessToken: NoteFixtures.accessToken)
            XCTFail("Expected notSupported")
        } catch NoteRepositoryError.notSupported {
            // expected
        }
    }

    func testMonolithicWriteNoteIsUnsupported() async throws {
        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())

        do {
            _ = try await client.writeNote(
                noteID: NoteFixtures.noteID,
                data: NoteFixtures.noteBytes,
                accessToken: NoteFixtures.accessToken
            )
            XCTFail("Expected notSupported")
        } catch NoteRepositoryError.notSupported {
            // expected
        }
    }

    func testMonolithicChunkedUploadIsUnsupported() async throws {
        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())

        do {
            _ = try await client.initUpload(
                noteID: NoteFixtures.noteID,
                totalSize: 1,
                accessToken: NoteFixtures.accessToken
            )
            XCTFail("Expected notSupported")
        } catch NoteRepositoryError.notSupported {
            // expected
        }
    }
}
