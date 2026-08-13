import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class LocalNoteRepositoryReadSharedNoteTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUp() {
        super.setUp()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        try? FileManager.default.removeItem(at: temporaryDirectory)
        temporaryDirectory = nil
        super.tearDown()
    }

    func testCachedBodyWithMatchingEtagReturnsLocalWithoutNetwork() async throws {
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)
        let noteID = NoteFixtures.noteID
        try await NoteTestSupport.openIndexStore(indexStore)
        try await indexStore.upsertSharedNote(
            SharedNoteIndexRow(
                summary: NoteFixtures.sampleSharedSummary,
                bodyEtag: NoteFixtures.sampleSharedSummary.etag
            )
        )
        try await repository.writeSharedBodyFileForTest(NoteFixtures.noteBytes, noteID: noteID)

        let requestCounter = RequestCounter()
        URLProtocolStub.requestHandler = { request in
            requestCounter.increment()
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.readSharedBodyJSON())
        }
        let remote = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )
        await repository.setSharedBodyImporter(remote)

        let shared = try await repository.readSharedNote(noteID: noteID)

        XCTAssertEqual(shared.noteID, noteID)
        XCTAssertEqual(requestCounter.value, 0)
    }

    func testMissingCacheImportsViaSplitBodyAndPersists() async throws {
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)
        let noteID = NoteFixtures.noteID
        try await NoteTestSupport.openIndexStore(indexStore)
        try await indexStore.upsertSharedNote(
            SharedNoteIndexRow(summary: NoteFixtures.sampleSharedSummary)
        )

        let captured = RequestCapture()
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.readSharedBodyJSON())
        }
        let remote = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )
        await repository.setSharedBodyImporter(remote)

        _ = try await repository.readSharedNote(noteID: noteID)

        XCTAssertEqual(
            captured.path,
            "/v1/notes/shared/\(noteID.uuidString.lowercased())/body"
        )
        let row = try await indexStore.fetchSharedNote(noteID: noteID)
        XCTAssertEqual(row?.bodyEtag, NoteFixtures.sampleSharedSummary.etag)
        let sharedBodyURL = temporaryDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("shared", isDirectory: true)
            .appendingPathComponent(noteID.uuidString, isDirectory: true)
            .appendingPathComponent("body")
        XCTAssertTrue(FileManager.default.fileExists(atPath: sharedBodyURL.path))
    }

    func testStaleEtagReimportsBody() async throws {
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)
        let noteID = NoteFixtures.noteID
        try await NoteTestSupport.openIndexStore(indexStore)
        try await indexStore.upsertSharedNote(
            SharedNoteIndexRow(
                summary: NoteFixtures.sampleSharedSummary,
                bodyEtag: #"W/"stale""#
            )
        )
        try await repository.writeSharedBodyFileForTest(NoteFixtures.noteBytes, noteID: noteID)

        let requestCounter = RequestCounter()
        URLProtocolStub.requestHandler = { request in
            requestCounter.increment()
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.readSharedBodyJSON())
        }
        let remote = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )
        await repository.setSharedBodyImporter(remote)

        _ = try await repository.readSharedNote(noteID: noteID)

        XCTAssertEqual(requestCounter.value, 1)
    }
}

private final class RequestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}

private extension LocalNoteRepository {
    func writeSharedBodyFileForTest(_ bodyData: Data, noteID: UUID) throws {
        try writeSharedBodyFile(bodyData, noteID: noteID)
    }
}
