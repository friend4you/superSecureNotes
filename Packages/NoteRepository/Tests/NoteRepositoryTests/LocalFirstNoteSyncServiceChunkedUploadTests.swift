import NoteRepositoryProtocol
import SecureCrypto
import VaultRepository
import XCTest

@testable import NoteRepository

final class LocalFirstNoteSyncServiceChunkedUploadTests: XCTestCase {
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

    func testFlushResumesChunkedUploadSkippingCompletedChunks() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440051")!
        let uploadID = NoteFixtures.uploadID
        let chunkSize = 5_000_000
        let log = RequestLog()
        let (indexStore, localRepository, _, _, syncService) = makeSyncEnvironment()
        let note = try NoteTestSupport.makeStoredNoteWithWireBlobSize(
            noteID: noteID,
            title: "Resume upload",
            wireBlobSize: NoteUploadSizeThreshold + 1
        )
        let initPath = "/v1/notes/\(noteID.uuidString.lowercased())/uploads"

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            return try self.handleChunkedUpload(
                request: request,
                noteID: noteID,
                uploadID: uploadID,
                chunkSize: chunkSize,
                failChunkIndex: nil
            )
        }

        try await NoteTestSupport.openIndexStore(indexStore)
        try await localRepository.writeNote(note)
        try await indexStore.upsertUploadSession(
            NoteUploadSessionRecord(
                noteID: noteID,
                uploadID: uploadID,
                wireSize: NoteUploadSizeThreshold + 1,
                chunkSize: chunkSize,
                totalChunks: 3,
                completedChunkIndices: [0]
            )
        )

        await syncService.flushPending()

        XCTAssertFalse(log.paths.contains(initPath))
        XCTAssertEqual(log.paths.filter { $0.contains("/chunks/0") }.count, 0)
        XCTAssertEqual(log.paths.filter { $0.contains("/chunks/1") }.count, 1)
        XCTAssertEqual(log.paths.filter { $0.contains("/chunks/2") }.count, 1)
        let sessionAfterFlush = try await indexStore.fetchUploadSession(noteID: noteID)
        XCTAssertNil(sessionAfterFlush)

        let row = try await indexStore.fetchNote(noteID: noteID)
        XCTAssertEqual(row?.syncState, .synced)
    }

    func testFlushInvalidatesSessionWhenWireSizeChanges() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440052")!
        let staleUploadID = UUID(uuidString: "770e8400-e29b-41d4-a716-446655440052")!
        let freshUploadID = NoteFixtures.uploadID
        let chunkSize = 5_000_000
        let log = RequestLog()
        let (indexStore, localRepository, _, _, syncService) = makeSyncEnvironment()
        let note = try NoteTestSupport.makeStoredNoteWithWireBlobSize(
            noteID: noteID,
            title: "Edited upload",
            wireBlobSize: NoteUploadSizeThreshold + 100
        )

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let activeUploadID = log.paths.contains { $0.contains(staleUploadID.uuidString.lowercased()) }
                ? staleUploadID
                : freshUploadID
            return try self.handleChunkedUpload(
                request: request,
                noteID: noteID,
                uploadID: activeUploadID,
                chunkSize: chunkSize,
                failChunkIndex: nil
            )
        }

        try await NoteTestSupport.openIndexStore(indexStore)
        try await localRepository.writeNote(note)
        try await indexStore.upsertUploadSession(
            NoteUploadSessionRecord(
                noteID: noteID,
                uploadID: staleUploadID,
                wireSize: NoteUploadSizeThreshold + 1,
                chunkSize: chunkSize,
                totalChunks: 3,
                completedChunkIndices: [0]
            )
        )

        await syncService.flushPending()

        XCTAssertEqual(log.paths.filter { $0.contains("/uploads") && !$0.contains("/chunks/") && !$0.hasSuffix("/complete") }.count, 1)
        XCTAssertFalse(log.paths.contains { $0.contains(staleUploadID.uuidString.lowercased()) })
        XCTAssertTrue(log.paths.contains { $0.contains(freshUploadID.uuidString.lowercased()) })
    }

    func testFlushRestartsWhenServerUploadSessionMissing() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440053")!
        let staleUploadID = UUID(uuidString: "880e8400-e29b-41d4-a716-446655440053")!
        let freshUploadID = NoteFixtures.uploadID
        let chunkSize = 5_000_000
        let log = RequestLog()
        let (indexStore, localRepository, _, _, syncService) = makeSyncEnvironment()
        let note = try NoteTestSupport.makeStoredNoteWithWireBlobSize(
            noteID: noteID,
            title: "Expired session",
            wireBlobSize: NoteUploadSizeThreshold + 1
        )

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let path = request.url!.path
            if path.contains(staleUploadID.uuidString.lowercased()) && path.contains("/chunks/") {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 404)
                return (response, NoteFixtures.errorJSON(error: "note_not_found", message: "Upload session missing."))
            }
            let activeUploadID = path.contains(staleUploadID.uuidString.lowercased()) ? staleUploadID : freshUploadID
            return try self.handleChunkedUpload(
                request: request,
                noteID: noteID,
                uploadID: activeUploadID,
                chunkSize: chunkSize,
                failChunkIndex: nil
            )
        }

        try await NoteTestSupport.openIndexStore(indexStore)
        try await localRepository.writeNote(note)
        try await indexStore.upsertUploadSession(
            NoteUploadSessionRecord(
                noteID: noteID,
                uploadID: staleUploadID,
                wireSize: NoteUploadSizeThreshold + 1,
                chunkSize: chunkSize,
                totalChunks: 3
            )
        )

        await syncService.flushPending()

        XCTAssertEqual(log.paths.filter { $0.contains("/uploads") && !$0.contains("/chunks/") && !$0.hasSuffix("/complete") }.count, 1)
        XCTAssertTrue(log.paths.contains { $0.contains(freshUploadID.uuidString.lowercased()) })
        let sessionAfterFlush = try await indexStore.fetchUploadSession(noteID: noteID)
        XCTAssertNil(sessionAfterFlush)
    }

    private func handleChunkedUpload(
        request: URLRequest,
        noteID: UUID,
        uploadID: UUID,
        chunkSize: Int,
        failChunkIndex: Int?
    ) throws -> (HTTPURLResponse, Data?) {
        let path = request.url!.path
        let initPath = "/v1/notes/\(noteID.uuidString.lowercased())/uploads"

        if path == initPath {
            guard
                let bodyData = TestHTTP.bodyData(from: request),
                let body = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
                let totalSize = body["totalSize"] as? Int
            else {
                XCTFail("Missing init request body")
                return (TestHTTP.makeResponse(url: request.url!, statusCode: 400), Data())
            }
            let totalChunks = (totalSize + chunkSize - 1) / chunkSize
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (
                response,
                NoteFixtures.uploadInitResponseJSON(
                    uploadId: uploadID,
                    chunkSize: chunkSize,
                    totalChunks: totalChunks
                )
            )
        }

        if path.contains("/chunks/") {
            if let failChunkIndex,
               path.hasSuffix("/chunks/\(failChunkIndex)") {
                throw URLError(.networkConnectionLost)
            }
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 204)
            return (response, nil)
        }

        if path.hasSuffix("/complete") {
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.writeNoteResponseJSON())
        }

        XCTFail("Unexpected path: \(path)")
        return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
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
