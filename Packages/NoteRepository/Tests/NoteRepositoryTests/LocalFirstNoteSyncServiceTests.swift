import NoteRepositoryProtocol
import SecureCrypto
import VaultRepository
import VaultRepositoryProtocol
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
        let (indexStore, localRepository, _, _, syncService) = makeSyncEnvironment()

        URLProtocolStub.requestHandler = { request in
            if let response = NoteFixtures.pullCatalogGETResponse(for: request) {
                return response
            }
            let path = request.url!.path
            if path.hasSuffix("/attachments") && request.httpMethod == "GET" {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, NoteFixtures.attachmentsManifestJSON())
            }
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
        let (indexStore, localRepository, _, _, syncService) = makeSyncEnvironment()
        let requestCounter = RequestCounter()

        URLProtocolStub.requestHandler = { request in
            requestCounter.increment()
            if let response = NoteFixtures.pullCatalogGETResponse(for: request) {
                return response
            }
            let path = request.url!.path
            if path.hasSuffix("/attachments") && request.httpMethod == "GET" {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, NoteFixtures.attachmentsManifestJSON())
            }
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.writeNoteResponseJSON())
        }

        try await NoteTestSupport.openIndexStore(indexStore)
        try await localRepository.writeNote(
            NoteTestSupport.makeSampleStoredNote(noteID: noteID, title: "Local only")
        )

        XCTAssertEqual(requestCounter.value, 0)

        await syncService.flushPending()

        XCTAssertEqual(requestCounter.value, 4)
    }

    func testFlushRetriesUploadWhenLocalNewerAfter409() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440032")!
        let (indexStore, localRepository, _, _, syncService) = makeSyncEnvironment()
        var putAttempts = 0

        URLProtocolStub.requestHandler = { request in
            if let response = NoteFixtures.pullCatalogGETResponse(for: request) {
                return response
            }
            let path = request.url!.path
            switch request.httpMethod {
            case "PUT":
                putAttempts += 1
                if putAttempts == 1 {
                    let response = TestHTTP.makeResponse(url: request.url!, statusCode: 409)
                    return (
                        response,
                        NoteFixtures.errorJSON(error: "conflict", message: "Note etag does not match.")
                    )
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
                XCTAssertTrue(path.hasSuffix("/attachments"))
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, NoteFixtures.attachmentsManifestJSON())
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

    func testFlushRetriesFromLocalWhenRemoteNewerAfter409() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440033")!
        let (indexStore, localRepository, _, _, syncService) = makeSyncEnvironment()
        var putAttempts = 0

        URLProtocolStub.requestHandler = { request in
            if let response = NoteFixtures.pullCatalogGETResponse(for: request) {
                return response
            }
            let path = request.url!.path
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
                        updatedAt: 1_700_000_400,
                        etag: #"W/"local-wins-etag""#
                    )
                )
            case "GET":
                XCTAssertTrue(path.hasSuffix("/attachments"))
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, NoteFixtures.attachmentsManifestJSON())
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

        XCTAssertEqual(putAttempts, 2)
        let readNote = try await localRepository.readNote(noteID: noteID)
        XCTAssertEqual(readNote.metadata.title, "Local older")
        XCTAssertEqual(readNote.metadata.updatedAt, 1_700_000_400)
        XCTAssertEqual(readNote.syncState, .synced)
        let row = try await indexStore.fetchNote(noteID: noteID)
        XCTAssertEqual(row?.etag, #"W/"local-wins-etag""#)
        XCTAssertEqual(row?.updatedAt, 1_700_000_400)
    }

    func testFlushDeletesRemotePendingDeleteNote() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440034")!
        let (indexStore, localRepository, _, _, syncService) = makeSyncEnvironment()
        let log = RequestLog()

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            if let response = NoteFixtures.pullCatalogGETResponse(for: request) {
                return response
            }
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

        XCTAssertTrue(
            log.paths.contains("/v1/notes/\(noteID.uuidString.lowercased())")
        )
        let deleteIndex = try XCTUnwrap(
            log.paths.firstIndex(of: "/v1/notes/\(noteID.uuidString.lowercased())")
        )
        XCTAssertEqual(log.method(at: deleteIndex), "DELETE")
        let rowAfterFlush = try await indexStore.fetchNote(noteID: noteID)
        XCTAssertNil(rowAfterFlush)
    }

    func testFlushKeepsPendingDeleteOnRemoteFailure() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440035")!
        let (indexStore, localRepository, _, _, syncService) = makeSyncEnvironment()

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

    func testPullVaultHeaderIfLocalMissingFetchesAndWritesWhenLocalMissing() async throws {
        let (_, _, localVault, _, syncService) = makeSyncEnvironment()
        let captured = RequestCapture()

        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.vaultHeaderBytes)
        }

        let header = try await syncService.pullVaultHeaderIfLocalMissing()

        XCTAssertEqual(header, NoteFixtures.vaultHeaderBytes)
        XCTAssertEqual(captured.method, "GET")
        XCTAssertEqual(captured.path, "/v1/vault/header")
        let localHeader = try await localVault.readHeader()
        XCTAssertEqual(localHeader, NoteFixtures.vaultHeaderBytes)
    }

    func testPullVaultHeaderIfLocalMissingReturnsNilWhenLocalExists() async throws {
        let (_, _, localVault, _, syncService) = makeSyncEnvironment()
        let requestCounter = RequestCounter()

        URLProtocolStub.requestHandler = { request in
            requestCounter.increment()
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, Data())
        }

        try await localVault.writeHeader(NoteFixtures.vaultHeaderBytes)
        let result = try await syncService.pullVaultHeaderIfLocalMissing()

        XCTAssertNil(result)
        XCTAssertEqual(requestCounter.value, 0)
    }

    func testPullRemoteNotesCatalogImportsNotesWhenIndexOpen() async throws {
        let noteID = NoteFixtures.noteID
        let (indexStore, localRepository, _, _, syncService) = makeSyncEnvironment()

        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            switch request.url?.path {
            case "/v1/notes":
                return (
                    response,
                    NoteFixtures.pullListNotesJSON(
                        noteID: noteID,
                        title: "Remote note",
                        updatedAt: 1_700_000_100,
                        etag: #"W/"remote-etag""#
                    )
                )
            case "/v1/notes/\(noteID.uuidString.lowercased())/body":
                return (response, NoteFixtures.noteBytes)
            default:
                XCTFail("Unexpected path: \(request.url?.path ?? "")")
                return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
            }
        }

        try await NoteTestSupport.openIndexStore(indexStore)
        try await syncService.pullRemoteNotesCatalog()

        let summaries = try await localRepository.listNotes()
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries[0].noteID, noteID)
        XCTAssertEqual(summaries[0].syncState, .synced)

        let row = try await indexStore.fetchNote(noteID: noteID)
        XCTAssertEqual(row?.syncState, .synced)
        XCTAssertEqual(row?.etag, #"W/"remote-etag""#)
    }

    func testPullRemoteNotesCatalogFailsWhenIndexNotOpen() async throws {
        let noteID = NoteFixtures.noteID
        let (_, _, _, _, syncService) = makeSyncEnvironment()

        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            switch request.url?.path {
            case "/v1/notes":
                return (
                    response,
                    NoteFixtures.pullListNotesJSON(
                        noteID: noteID,
                        title: "Remote note",
                        updatedAt: 1_700_000_100,
                        etag: #"W/"remote-etag""#
                    )
                )
            case "/v1/notes/\(noteID.uuidString.lowercased())/body":
                return (response, NoteFixtures.noteBytes)
            default:
                return (response, Data())
            }
        }

        do {
            try await syncService.pullRemoteNotesCatalog()
            XCTFail("Expected databaseNotOpen")
        } catch NoteRepositoryError.databaseNotOpen {
            // expected
        }
    }

    func testUploadVaultHeaderOrThrowSucceedsOn204() async throws {
        let header = Data([0xAA, 0xBB])
        let captured = RequestCapture()

        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 204)
            return (response, nil)
        }

        let (_, _, _, _, syncService) = makeSyncEnvironment()
        try await syncService.uploadVaultHeaderOrThrow(header)

        XCTAssertEqual(captured.method, "PUT")
        XCTAssertEqual(captured.path, "/v1/vault/header")
        XCTAssertEqual(captured.contentType, "application/octet-stream")
        XCTAssertEqual(captured.bodyData, header)
    }

    func testUploadVaultHeaderOrThrowThrowsOnServerError() async throws {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 500)
            return (response, Data())
        }

        let (_, _, _, _, syncService) = makeSyncEnvironment()

        do {
            try await syncService.uploadVaultHeaderOrThrow(Data([0x01]))
            XCTFail("Expected serverError")
        } catch VaultRepositoryError.serverError(let statusCode, _) {
            XCTAssertEqual(statusCode, 500)
        }
    }

    func testPullCatalogImportsVaultHeaderAndNotesWhenLocalVaultMissing() async throws {
        let noteID = NoteFixtures.noteID
        let (indexStore, localRepository, localVault, _, syncService) = makeSyncEnvironment()

        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            switch request.url?.path {
            case "/v1/vault/header":
                return (response, NoteFixtures.vaultHeaderBytes)
            case "/v1/notes":
                return (
                    response,
                    NoteFixtures.pullListNotesJSON(
                        noteID: noteID,
                        title: "Remote note",
                        updatedAt: 1_700_000_100,
                        etag: #"W/"remote-etag""#
                    )
                )
            case "/v1/notes/\(noteID.uuidString.lowercased())/body":
                return (response, NoteFixtures.noteBytes)
            default:
                XCTFail("Unexpected path: \(request.url?.path ?? "")")
                return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
            }
        }

        try await NoteTestSupport.openIndexStore(indexStore)
        let header = try await syncService.pullCatalogIfLocalVaultMissing()

        XCTAssertEqual(header, NoteFixtures.vaultHeaderBytes)
        let localHeader = try await localVault.readHeader()
        XCTAssertEqual(localHeader, NoteFixtures.vaultHeaderBytes)

        let summaries = try await localRepository.listNotes()
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries[0].noteID, noteID)
        XCTAssertEqual(summaries[0].syncState, .synced)

        let row = try await indexStore.fetchNote(noteID: noteID)
        XCTAssertEqual(row?.syncState, .synced)
        XCTAssertEqual(row?.etag, #"W/"remote-etag""#)
    }

    func testPullCatalogSkipsWhenLocalVaultExists() async throws {
        let (_, _, localVault, _, syncService) = makeSyncEnvironment()
        let requestCounter = RequestCounter()

        URLProtocolStub.requestHandler = { request in
            requestCounter.increment()
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, Data())
        }

        try await localVault.writeHeader(NoteFixtures.vaultHeaderBytes)
        let result = try await syncService.pullCatalogIfLocalVaultMissing()

        XCTAssertNil(result)
        XCTAssertEqual(requestCounter.value, 0)
    }

    func testScheduleVaultHeaderUploadSendsPUTWithoutBlocking() async throws {
        let header = Data([0xAA, 0xBB])
        let captured = RequestCapture()
        let uploadStarted = expectation(description: "vault upload started")

        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            uploadStarted.fulfill()
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 204)
            return (response, nil)
        }

        let (_, _, _, _, syncService) = makeSyncEnvironment()
        syncService.scheduleVaultHeaderUpload(header)

        await fulfillment(of: [uploadStarted], timeout: 1.0)
        XCTAssertEqual(captured.method, "PUT")
        XCTAssertEqual(captured.path, "/v1/vault/header")
        XCTAssertEqual(captured.contentType, "application/octet-stream")
        XCTAssertEqual(captured.bodyData, header)
    }

    private func makeRemoteRepository() -> NetworkNoteRepository {
        NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )
    }

    private func makeSyncEnvironment() -> (
        NotesIndexStore,
        LocalNoteRepository,
        LocalVaultRepository,
        NetworkVaultRepository,
        LocalFirstNoteSyncService
    ) {
        let vaultDirectory = temporaryDirectory.appendingPathComponent("vault", isDirectory: true)
        let localVault = LocalVaultRepository(vaultDirectoryURL: vaultDirectory)
        let remoteVault = NetworkVaultRepository(
            apiClient: VaultAPIClient(
                baseURL: NoteFixtures.baseURL,
                tokenProvider: MockTokenProvider(),
                session: .stubbed()
            )
        )
        let (indexStore, localRepository) = NoteTestSupport.makeLocalRepository(
            notesRootURL: temporaryDirectory
        )
        let syncService = LocalFirstNoteSyncService(
            localNotes: localRepository,
            remoteNotes: makeRemoteRepository(),
            localVault: localVault,
            remoteVault: remoteVault
        )
        return (indexStore, localRepository, localVault, remoteVault, syncService)
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
