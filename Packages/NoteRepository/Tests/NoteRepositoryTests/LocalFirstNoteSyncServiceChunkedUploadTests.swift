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
        let attachmentID = NoteFixtures.attachmentID
        let uploadID = NoteFixtures.uploadID
        let chunkSize = 5_000_000
        let ciphertext = Data(repeating: 0xAA, count: NoteUploadSizeThreshold + 1)
        let log = RequestLog()
        let (indexStore, localRepository, _, _, syncService) = makeSyncEnvironment()
        let initPath =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())/uploads"
        let bodyPath = "/v1/notes/\(noteID.uuidString.lowercased())/body"
        let manifestPath = "/v1/notes/\(noteID.uuidString.lowercased())/attachments"

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let path = request.url!.path
            if path == bodyPath {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, NoteFixtures.writeNoteResponseJSON())
            }
            if path == manifestPath && request.httpMethod == "GET" {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, NoteFixtures.attachmentsManifestJSON(attachments: []))
            }
            return try self.handleChunkedUpload(
                request: request,
                noteID: noteID,
                attachmentID: attachmentID,
                uploadID: uploadID,
                chunkSize: chunkSize,
                failChunkIndex: nil
            )
        }

        try await NoteTestSupport.openIndexStore(indexStore)
        try await localRepository.writeNote(
            makeLargeAttachmentNote(noteID: noteID, attachmentID: attachmentID, ciphertext: ciphertext)
        )
        try await indexStore.upsertAttachmentUploadSession(
            AttachmentUploadSessionRecord(
                noteID: noteID,
                attachmentID: attachmentID,
                uploadID: uploadID,
                wireSize: ciphertext.count,
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
        let sessionAfterFlush = try await indexStore.fetchAttachmentUploadSession(
            noteID: noteID,
            attachmentID: attachmentID
        )
        XCTAssertNil(sessionAfterFlush)

        let row = try await indexStore.fetchNote(noteID: noteID)
        XCTAssertEqual(row?.syncState, .synced)
    }

    func testFlushInvalidatesSessionWhenWireSizeChanges() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440052")!
        let attachmentID = NoteFixtures.attachmentID
        let staleUploadID = UUID(uuidString: "770e8400-e29b-41d4-a716-446655440052")!
        let freshUploadID = NoteFixtures.uploadID
        let chunkSize = 5_000_000
        let ciphertext = Data(repeating: 0xAA, count: NoteUploadSizeThreshold + 100)
        let log = RequestLog()
        let (indexStore, localRepository, _, _, syncService) = makeSyncEnvironment()

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let path = request.url!.path
            if path.hasSuffix("/body") {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, NoteFixtures.writeNoteResponseJSON())
            }
            if path.hasSuffix("/attachments") && request.httpMethod == "GET" {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, NoteFixtures.attachmentsManifestJSON(attachments: []))
            }
            let activeUploadID = log.paths.contains { $0.contains(staleUploadID.uuidString.lowercased()) }
                ? staleUploadID
                : freshUploadID
            return try self.handleChunkedUpload(
                request: request,
                noteID: noteID,
                attachmentID: attachmentID,
                uploadID: activeUploadID,
                chunkSize: chunkSize,
                failChunkIndex: nil
            )
        }

        try await NoteTestSupport.openIndexStore(indexStore)
        try await localRepository.writeNote(
            makeLargeAttachmentNote(noteID: noteID, attachmentID: attachmentID, ciphertext: ciphertext)
        )
        try await indexStore.upsertAttachmentUploadSession(
            AttachmentUploadSessionRecord(
                noteID: noteID,
                attachmentID: attachmentID,
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
        let attachmentID = NoteFixtures.attachmentID
        let staleUploadID = UUID(uuidString: "880e8400-e29b-41d4-a716-446655440053")!
        let freshUploadID = NoteFixtures.uploadID
        let chunkSize = 5_000_000
        let ciphertext = Data(repeating: 0xAA, count: NoteUploadSizeThreshold + 1)
        let log = RequestLog()
        let (indexStore, localRepository, _, _, syncService) = makeSyncEnvironment()

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let path = request.url!.path
            if path.hasSuffix("/body") {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, NoteFixtures.writeNoteResponseJSON())
            }
            if path.hasSuffix("/attachments") && request.httpMethod == "GET" {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, NoteFixtures.attachmentsManifestJSON(attachments: []))
            }
            if path.contains(staleUploadID.uuidString.lowercased()) && path.contains("/chunks/") {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 404)
                return (response, NoteFixtures.errorJSON(error: "note_not_found", message: "Upload session missing."))
            }
            let activeUploadID = path.contains(staleUploadID.uuidString.lowercased()) ? staleUploadID : freshUploadID
            return try self.handleChunkedUpload(
                request: request,
                noteID: noteID,
                attachmentID: attachmentID,
                uploadID: activeUploadID,
                chunkSize: chunkSize,
                failChunkIndex: nil
            )
        }

        try await NoteTestSupport.openIndexStore(indexStore)
        try await localRepository.writeNote(
            makeLargeAttachmentNote(noteID: noteID, attachmentID: attachmentID, ciphertext: ciphertext)
        )
        try await indexStore.upsertAttachmentUploadSession(
            AttachmentUploadSessionRecord(
                noteID: noteID,
                attachmentID: attachmentID,
                uploadID: staleUploadID,
                wireSize: ciphertext.count,
                chunkSize: chunkSize,
                totalChunks: 3
            )
        )

        await syncService.flushPending()

        XCTAssertEqual(log.paths.filter { $0.contains("/uploads") && !$0.contains("/chunks/") && !$0.hasSuffix("/complete") }.count, 1)
        XCTAssertTrue(log.paths.contains { $0.contains(freshUploadID.uuidString.lowercased()) })
        let sessionAfterFlush = try await indexStore.fetchAttachmentUploadSession(
            noteID: noteID,
            attachmentID: attachmentID
        )
        XCTAssertNil(sessionAfterFlush)
    }

    private func makeLargeAttachmentNote(
        noteID: UUID,
        attachmentID: UUID,
        ciphertext: Data
    ) -> StoredNote {
        StoredNote(
            metadata: NoteMetadata(
                noteID: noteID,
                title: "Large attachment",
                createdAt: 1_700_000_000,
                updatedAt: 1_700_000_100,
                attachmentCount: 1,
                attachmentsTotalSize: UInt64(ciphertext.count)
            ),
            wrappedFEK: Data(repeating: 0xAB, count: 60),
            encryptedPayload: Data(repeating: 0xCD, count: 128),
            syncState: .pendingSync,
            attachmentCiphertexts: [attachmentID: ciphertext]
        )
    }

    private func handleChunkedUpload(
        request: URLRequest,
        noteID: UUID,
        attachmentID: UUID,
        uploadID: UUID,
        chunkSize: Int,
        failChunkIndex: Int?
    ) throws -> (HTTPURLResponse, Data?) {
        if let response = NoteFixtures.pullCatalogGETResponse(for: request) {
            return response
        }
        let path = request.url!.path
        let initPath =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())/uploads"

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
            return (response, NoteFixtures.writeAttachmentResponseJSON())
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
