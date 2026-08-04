import NoteRepositoryProtocol
import SecureCrypto
import XCTest

@testable import NoteRepository

final class LocalFirstNoteSyncServiceTests: XCTestCase {
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

    func testFlushUploadsPendingSyncNoteAndMarksSyncedOn200() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440030")!
        let (indexStore, localRepository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)
        let remoteRepository = makeRemoteRepository()
        let syncService = LocalFirstNoteSyncService(
            localNotes: localRepository,
            remoteNotes: remoteRepository
        )

        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "PUT")
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (
                response,
                NoteFixtures.writeNoteResponseJSON(
                    syncState: "synced",
                    updatedAt: 1_800_000_000,
                    etag: #"W/"synced-etag""#
                )
            )
        }

        try await NoteTestSupport.openIndexStore(indexStore)
        try await localRepository.writeNote(
            NoteTestSupport.makeSampleStoredNote(noteID: noteID, title: "Pending upload")
        )

        await syncService.flushPending()

        let summaries = try await localRepository.listNotes()
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries[0].syncState, .synced)

        let row = try await indexStore.fetchNote(noteID: noteID)
        XCTAssertEqual(row?.syncState, .synced)
        XCTAssertEqual(row?.etag, #"W/"synced-etag""#)
        XCTAssertEqual(row?.updatedAt, 1_800_000_000)
    }

    func testWriteNoteDoesNotAwaitNetwork() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440031")!
        let (indexStore, localRepository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)
        let remoteRepository = makeRemoteRepository()
        let syncService = LocalFirstNoteSyncService(
            localNotes: localRepository,
            remoteNotes: remoteRepository
        )
        let requestCounter = RequestCounter()

        URLProtocolStub.requestHandler = { request in
            requestCounter.increment()
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.writeNoteResponseJSON())
        }

        try await NoteTestSupport.openIndexStore(indexStore)
        try await localRepository.writeNote(
            NoteTestSupport.makeSampleStoredNote(noteID: noteID, title: "Local only")
        )

        XCTAssertEqual(requestCounter.value, 0)

        await syncService.flushPending()

        XCTAssertEqual(requestCounter.value, 1)
    }

    func testFlushRetriesUploadWhenLocalNewerAfter409() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440032")!
        let (indexStore, localRepository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)
        let remoteRepository = makeRemoteRepository()
        let syncService = LocalFirstNoteSyncService(
            localNotes: localRepository,
            remoteNotes: remoteRepository
        )
        let remoteWireNote = try NoteTestSupport.makeSampleWireNote(
            noteID: noteID,
            title: "Remote older",
            updatedAt: 1_700_000_100
        )
        var putAttempts = 0

        URLProtocolStub.requestHandler = { request in
            switch request.httpMethod {
            case "PUT":
                putAttempts += 1
                if putAttempts == 1 {
                    let response = TestHTTP.makeResponse(url: request.url!, statusCode: 409)
                    return (response, Data())
                }
                XCTAssertNil(request.value(forHTTPHeaderField: "If-Match"))
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (
                    response,
                    NoteFixtures.writeNoteResponseJSON(
                        updatedAt: 1_700_000_300,
                        etag: #"W/"retry-etag""#
                    )
                )
            case "GET":
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, remoteWireNote)
            default:
                XCTFail("Unexpected method: \(request.httpMethod ?? "")")
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 500)
                return (response, Data())
            }
        }

        try await NoteTestSupport.openIndexStore(indexStore)
        try await localRepository.writeNote(
            NoteTestSupport.makeSampleStoredNote(
                noteID: noteID,
                title: "Local newer",
                updatedAt: 1_700_000_200,
                syncState: .pendingSync
            )
        )
        try await indexStore.upsertNote(
            NoteIndexRow(
                noteID: noteID,
                title: "Local newer",
                createdAt: 1_700_000_000,
                updatedAt: 1_700_000_200,
                attachmentCount: 0,
                attachmentsTotalSize: 0,
                wrappedFEK: Data(repeating: 0xAB, count: 60),
                syncState: .pendingSync,
                etag: #"W/"stale-etag""#
            )
        )

        await syncService.flushPending()

        XCTAssertEqual(putAttempts, 2)
        let readNote = try await localRepository.readNote(noteID: noteID)
        XCTAssertEqual(readNote.metadata.title, "Local newer")
        XCTAssertEqual(readNote.syncState, .synced)
        let row = try await indexStore.fetchNote(noteID: noteID)
        XCTAssertEqual(row?.etag, #"W/"retry-etag""#)
    }

    func testFlushOverwritesLocalWhenRemoteNewerAfter409() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440033")!
        let (indexStore, localRepository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)
        let remoteRepository = makeRemoteRepository()
        let syncService = LocalFirstNoteSyncService(
            localNotes: localRepository,
            remoteNotes: remoteRepository
        )
        let remoteWireNote = try NoteTestSupport.makeSampleWireNote(
            noteID: noteID,
            title: "Remote winner",
            updatedAt: 1_700_000_300
        )
        var putAttempts = 0

        URLProtocolStub.requestHandler = { request in
            switch request.httpMethod {
            case "PUT":
                putAttempts += 1
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 409)
                return (response, Data())
            case "GET":
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, remoteWireNote)
            default:
                XCTFail("Unexpected method: \(request.httpMethod ?? "")")
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 500)
                return (response, Data())
            }
        }

        try await NoteTestSupport.openIndexStore(indexStore)
        try await localRepository.writeNote(
            NoteTestSupport.makeSampleStoredNote(
                noteID: noteID,
                title: "Local older",
                updatedAt: 1_700_000_100,
                syncState: .pendingSync
            )
        )

        await syncService.flushPending()

        XCTAssertEqual(putAttempts, 1)
        let readNote = try await localRepository.readNote(noteID: noteID)
        XCTAssertEqual(readNote.metadata.title, "Remote winner")
        XCTAssertEqual(readNote.metadata.updatedAt, 1_700_000_300)
        XCTAssertEqual(readNote.syncState, .synced)
        let summaries = try await localRepository.listNotes()
        XCTAssertEqual(summaries[0].syncState, .synced)
    }

    func testFlushDeletesRemotePendingDeleteNote() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440034")!
        let (indexStore, localRepository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)
        let remoteRepository = makeRemoteRepository()
        let syncService = LocalFirstNoteSyncService(
            localNotes: localRepository,
            remoteNotes: remoteRepository
        )
        let captured = RequestCapture()

        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 204)
            return (response, nil)
        }

        try await NoteTestSupport.openIndexStore(indexStore)
        try await localRepository.writeNote(
            NoteTestSupport.makeSampleStoredNote(noteID: noteID, title: "Delete me")
        )
        try await localRepository.deleteNote(noteID: noteID)

        let summariesBeforeFlush = try await localRepository.listNotes()
        XCTAssertTrue(summariesBeforeFlush.isEmpty)

        await syncService.flushPending()

        XCTAssertEqual(captured.method, "DELETE")
        XCTAssertEqual(captured.path, "/v1/notes/\(noteID.uuidString.lowercased())")
        let rowAfterFlush = try await indexStore.fetchNote(noteID: noteID)
        XCTAssertNil(rowAfterFlush)
    }

    func testFlushKeepsPendingDeleteOnRemoteFailure() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440035")!
        let (indexStore, localRepository) = NoteTestSupport.makeLocalRepository(notesRootURL: temporaryDirectory)
        let remoteRepository = makeRemoteRepository()
        let syncService = LocalFirstNoteSyncService(
            localNotes: localRepository,
            remoteNotes: remoteRepository
        )

        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 500)
            return (response, Data())
        }

        try await NoteTestSupport.openIndexStore(indexStore)
        try await localRepository.writeNote(
            NoteTestSupport.makeSampleStoredNote(noteID: noteID, title: "Delete me")
        )
        try await localRepository.deleteNote(noteID: noteID)

        await syncService.flushPending()

        let summariesAfterFailedFlush = try await localRepository.listNotes()
        XCTAssertTrue(summariesAfterFailedFlush.isEmpty)
        let row = try await indexStore.fetchNote(noteID: noteID)
        XCTAssertEqual(row?.syncState, .pendingDelete)
    }

    private func makeRemoteRepository() -> NetworkNoteRepository {
        NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )
    }
}

private final class RequestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }
}
