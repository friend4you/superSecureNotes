import SecureCrypto
import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class NoteSharingRepositoryTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testNetworkListSharedNotesDelegatesToAPIClient() async throws {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.listSharedNotesJSON())
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        let notes = try await repository.listSharedNotes()
        XCTAssertEqual(notes, [NoteFixtures.sampleSharedSummary])
    }

    func testNetworkReadSharedNoteParsesBlobAndRecipientWrappedFEK() async throws {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.readSharedNoteJSON())
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        let shared = try await repository.readSharedNote(noteID: NoteFixtures.noteID)
        let sections = try parseNoteFile(NoteFixtures.noteBytes)

        XCTAssertEqual(shared.noteID, NoteFixtures.noteID)
        XCTAssertEqual(shared.metadata, sections.metadata)
        XCTAssertEqual(shared.recipientWrappedFEK, NoteFixtures.recipientWrappedFEK)
        XCTAssertEqual(shared.encryptedPayload, sections.encryptedPayload)
    }

    func testNetworkShareNoteDelegatesToAPIClient() async throws {
        let captured = RequestCapture()
        let wrappedFEK = Data(repeating: 0xEF, count: 32)
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 204)
            return (response, Data())
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        try await repository.shareNote(
            noteID: NoteFixtures.noteID,
            recipientEmail: "friend@example.com",
            wrappedFEK: wrappedFEK
        )

        XCTAssertEqual(captured.method, "POST")
        XCTAssertEqual(
            captured.path,
            "/v1/notes/\(NoteFixtures.noteID.uuidString.lowercased())/share"
        )
    }

    func testLocalListSharedNotesReturnsEmptyWhenIndexOpen() async throws {
        let notesRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: notesRootURL)
        try await NoteTestSupport.openIndexStore(indexStore)

        let notes = try await repository.listSharedNotes()
        XCTAssertTrue(notes.isEmpty)
    }

    func testLocalReadSharedNoteThrowsWhenNoImporterConfigured() async throws {
        let notesRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: notesRootURL)
        try await NoteTestSupport.openIndexStore(indexStore)
        try await indexStore.upsertSharedNote(
            SharedNoteIndexRow(summary: NoteFixtures.sampleSharedSummary)
        )

        do {
            _ = try await repository.readSharedNote(noteID: NoteFixtures.noteID)
            XCTFail("Expected notSupported")
        } catch let error as NoteRepositoryError {
            XCTAssertEqual(error, .notSupported)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLocalShareNoteThrowsNotSupported() async throws {
        let notesRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let (_, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: notesRootURL)

        do {
            try await repository.shareNote(
                noteID: NoteFixtures.noteID,
                recipientEmail: "friend@example.com",
                wrappedFEK: Data([0x01])
            )
            XCTFail("Expected notSupported")
        } catch let error as NoteRepositoryError {
            XCTAssertEqual(error, .notSupported)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testNetworkDeleteSharedNoteDelegatesToAPIClient() async throws {
        let captured = RequestCapture()
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 204)
            return (response, Data())
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        try await repository.deleteSharedNote(noteID: NoteFixtures.noteID)

        XCTAssertEqual(captured.method, "DELETE")
        XCTAssertEqual(
            captured.path,
            "/v1/notes/shared/\(NoteFixtures.noteID.uuidString.lowercased())"
        )
    }

    func testLocalDeleteSharedNoteRemovesIndexRow() async throws {
        let notesRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: notesRootURL)
        try await NoteTestSupport.openIndexStore(indexStore)
        try await indexStore.upsertSharedNote(
            SharedNoteIndexRow(summary: NoteFixtures.sampleSharedSummary)
        )

        try await repository.deleteSharedNote(noteID: NoteFixtures.noteID)

        let notes = try await repository.listSharedNotes()
        XCTAssertTrue(notes.isEmpty)
    }
}
