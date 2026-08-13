import NoteRepositoryProtocol
import VaultRepository
import XCTest

@testable import NoteRepository

final class NoteSyncOutcomeTests: XCTestCase {
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

    func testScheduleFlushStartsFlushWithoutBlockingCaller() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440060")!
        let (indexStore, localRepository, _, _, syncService) = makeSyncEnvironment()
        let flushStarted = expectation(description: "flush started")

        URLProtocolStub.requestHandler = { request in
            flushStarted.fulfill()
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.writeNoteResponseJSON())
        }

        try await NoteTestSupport.openIndexStore(indexStore)
        try await localRepository.writeNote(
            NoteTestSupport.makeSampleStoredNote(noteID: noteID, title: "Scheduled flush")
        )

        syncService.scheduleFlush()

        await fulfillment(of: [flushStarted], timeout: 1.0)
    }

    func testFlushEmitsUploadedOutcomeOnSuccess() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440061")!
        let (indexStore, localRepository, _, _, syncService) = makeSyncEnvironment()

        URLProtocolStub.requestHandler = { request in
            let path = request.url!.path
            if path.hasSuffix("/attachments") && request.httpMethod == "GET" {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, NoteFixtures.attachmentsManifestJSON())
            }
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (
                response,
                NoteFixtures.writeNoteResponseJSON(
                    syncState: "synced",
                    updatedAt: 1_800_000_100,
                    etag: #"W/"outcome-etag""#
                )
            )
        }

        try await NoteTestSupport.openIndexStore(indexStore)
        try await localRepository.writeNote(
            NoteTestSupport.makeSampleStoredNote(noteID: noteID, title: "Upload outcome")
        )

        let outcomeTask = Task {
            var iterator = syncService.syncOutcomes.makeAsyncIterator()
            return await iterator.next()
        }

        await syncService.flushPending()

        let outcome = await outcomeTask.value
        XCTAssertEqual(
            outcome,
            .uploaded(
                noteID: noteID,
                syncState: .synced,
                updatedAt: 1_800_000_100,
                etag: #"W/"outcome-etag""#
            )
        )
    }

    func testSyncOutcomesDeliverToMultipleSubscribers() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440063")!
        let (indexStore, localRepository, _, _, syncService) = makeSyncEnvironment()

        URLProtocolStub.requestHandler = { request in
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
            NoteTestSupport.makeSampleStoredNote(noteID: noteID, title: "Broadcast outcome")
        )

        let firstOutcomeTask = Task {
            var iterator = syncService.syncOutcomes.makeAsyncIterator()
            return await iterator.next()
        }
        let secondOutcomeTask = Task {
            var iterator = syncService.syncOutcomes.makeAsyncIterator()
            return await iterator.next()
        }
        try? await Task.sleep(nanoseconds: 10_000_000)

        await syncService.flushPending()

        let expected: NoteSyncOutcome = .uploaded(
            noteID: noteID,
            syncState: .synced,
            updatedAt: 1_700_000_100,
            etag: #"W/"abc123""#
        )
        let firstOutcome = await firstOutcomeTask.value
        let secondOutcome = await secondOutcomeTask.value
        XCTAssertEqual(firstOutcome, expected)
        XCTAssertEqual(secondOutcome, expected)
    }

    func testFlushEmitsUploadFailedOutcomeOnNetworkError() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440062")!
        let (indexStore, localRepository, _, _, syncService) = makeSyncEnvironment()

        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 500)
            return (response, Data())
        }

        try await NoteTestSupport.openIndexStore(indexStore)
        try await localRepository.writeNote(
            NoteTestSupport.makeSampleStoredNote(noteID: noteID, title: "Failed upload")
        )

        let outcomeTask = Task {
            var iterator = syncService.syncOutcomes.makeAsyncIterator()
            return await iterator.next()
        }

        await syncService.flushPending()

        let outcome = await outcomeTask.value
        XCTAssertEqual(outcome, .uploadFailed(noteID: noteID))
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
