import SecureCrypto
import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class NoteSharingAPIClientTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testSharedNoteSummaryIsEquatable() {
        let other = SharedNoteSummary(
            noteID: NoteFixtures.sampleSharedSummary.noteID,
            title: NoteFixtures.sampleSharedSummary.title,
            updatedAt: NoteFixtures.sampleSharedSummary.updatedAt,
            etag: NoteFixtures.sampleSharedSummary.etag,
            ownerEmail: NoteFixtures.sampleSharedSummary.ownerEmail,
            ownerID: NoteFixtures.sampleSharedSummary.ownerID,
            sharedAt: NoteFixtures.sampleSharedSummary.sharedAt
        )
        XCTAssertEqual(NoteFixtures.sampleSharedSummary, other)
    }

    func testSharedNoteCarriesDownloadPayload() throws {
        let sections = try parseNoteFile(NoteFixtures.noteBytes)
        let shared = SharedNote(
            noteID: NoteFixtures.noteID,
            metadata: sections.metadata,
            recipientWrappedFEK: NoteFixtures.recipientWrappedFEK,
            encryptedPayload: sections.encryptedPayload
        )

        XCTAssertEqual(shared.noteID, NoteFixtures.noteID)
        XCTAssertEqual(shared.metadata, sections.metadata)
        XCTAssertEqual(shared.recipientWrappedFEK, NoteFixtures.recipientWrappedFEK)
        XCTAssertEqual(shared.encryptedPayload, sections.encryptedPayload)
    }

    func testListSharedNotesSendsExpectedRequest() async throws {
        let captured = RequestCapture()
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.listSharedNotesJSON())
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        let notes = try await client.listSharedNotes(accessToken: NoteFixtures.accessToken)

        XCTAssertEqual(captured.method, "GET")
        XCTAssertEqual(captured.path, "/v1/notes/shared")
        XCTAssertEqual(captured.authorization, "Bearer \(NoteFixtures.accessToken)")
        XCTAssertEqual(notes, [NoteFixtures.sampleSharedSummary])
    }

    func testReadSharedNoteSendsExpectedRequestAndParsesResponse() async throws {
        let captured = RequestCapture()
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.readSharedNoteJSON())
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        let dto = try await client.readSharedNote(
            noteID: NoteFixtures.noteID,
            accessToken: NoteFixtures.accessToken
        )

        XCTAssertEqual(captured.method, "GET")
        XCTAssertEqual(
            captured.path,
            "/v1/notes/shared/\(NoteFixtures.noteID.uuidString.lowercased())"
        )
        XCTAssertEqual(captured.authorization, "Bearer \(NoteFixtures.accessToken)")
        XCTAssertEqual(dto.noteId, NoteFixtures.noteID.uuidString.lowercased())
        XCTAssertEqual(Data(base64Encoded: dto.wrappedFek), NoteFixtures.recipientWrappedFEK)
        XCTAssertEqual(Data(base64Encoded: dto.body), NoteFixtures.noteBytes)
    }

    func testShareNotePostsGrant() async throws {
        let captured = RequestCapture()
        let wrappedFEK = Data(repeating: 0xCD, count: 40)
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 204)
            return (response, Data())
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        try await client.shareNote(
            noteID: NoteFixtures.noteID,
            recipientEmail: "friend@example.com",
            wrappedFEK: wrappedFEK,
            accessToken: NoteFixtures.accessToken
        )

        XCTAssertEqual(captured.method, "POST")
        XCTAssertEqual(
            captured.path,
            "/v1/notes/\(NoteFixtures.noteID.uuidString.lowercased())/share"
        )
        XCTAssertEqual(captured.contentType, "application/json")
        XCTAssertEqual(captured.authorization, "Bearer \(NoteFixtures.accessToken)")

        let body = try XCTUnwrap(captured.bodyData)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: String]
        XCTAssertEqual(json?["recipientEmail"], "friend@example.com")
        XCTAssertEqual(json?["wrappedFek"], wrappedFEK.base64EncodedString())
    }

    func testDeleteSharedNoteSendsExpectedRequest() async throws {
        let captured = RequestCapture()
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 204)
            return (response, Data())
        }

        let client = NoteAPIClient(baseURL: NoteFixtures.baseURL, session: .stubbed())
        try await client.deleteSharedNote(
            noteID: NoteFixtures.noteID,
            accessToken: NoteFixtures.accessToken
        )

        XCTAssertEqual(captured.method, "DELETE")
        XCTAssertEqual(
            captured.path,
            "/v1/notes/shared/\(NoteFixtures.noteID.uuidString.lowercased())"
        )
        XCTAssertEqual(captured.authorization, "Bearer \(NoteFixtures.accessToken)")
    }
}
