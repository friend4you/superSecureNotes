import NoteRepositoryProtocol
import SecureCrypto
import VaultRepository
import XCTest

@testable import NoteRepository

final class LocalFirstNoteSyncServiceAttachmentUploadSessionTests: XCTestCase {
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

    func testFlushRetriesFullReuploadFromLocalOnEtagConflict() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440074")!
        let attachmentID = UUID(uuidString: "880e8400-e29b-41d4-a716-446655440074")!
        let (indexStore, localRepository, _, _, syncService) = makeSyncEnvironment()
        let log = RequestLog()
        var bodyAttempts = 0

        let bodyPath = "/v1/notes/\(noteID.uuidString.lowercased())/body"
        let attachmentPath =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())"
        let manifestPath = "/v1/notes/\(noteID.uuidString.lowercased())/attachments"

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            if let response = NoteFixtures.pullCatalogGETResponse(for: request) {
                return response
            }
            let path = request.url!.path

            if path == bodyPath {
                bodyAttempts += 1
                if bodyAttempts == 1 {
                    XCTAssertEqual(request.value(forHTTPHeaderField: "If-Match"), #"W/"stale-etag""#)
                    let response = TestHTTP.makeResponse(url: request.url!, statusCode: 409)
                    return (response, Data())
                }
                XCTAssertNil(request.value(forHTTPHeaderField: "If-Match"))
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (
                    response,
                    NoteFixtures.writeNoteResponseJSON(
                        updatedAt: 1_700_000_300,
                        etag: #"W/"retry-body-etag""#
                    )
                )
            }
            if path == manifestPath && request.httpMethod == "GET" {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, NoteFixtures.attachmentsManifestJSON(attachments: []))
            }
            if path == attachmentPath {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, NoteFixtures.writeAttachmentResponseJSON(noteEtag: #"W/"retry-note-etag""#))
            }
            XCTFail("Unexpected path: \(path)")
            return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
        }

        try await NoteTestSupport.openIndexStore(indexStore)
        try await localRepository.writeNote(
            makeNote(
                noteID: noteID,
                title: "Local wins",
                attachmentID: attachmentID,
                ciphertext: Data(repeating: 0x11, count: 20)
            )
        )
        try await indexStore.upsertNote(
            NoteIndexRow(
                noteID: noteID,
                title: "Local wins",
                createdAt: 1_700_000_000,
                updatedAt: 1_700_000_100,
                attachmentCount: 1,
                attachmentsTotalSize: 20,
                wrappedFEK: Data(repeating: 0xAB, count: 60),
                syncState: .pendingSync,
                etag: #"W/"stale-etag""#
            )
        )

        await syncService.flushPending()

        XCTAssertEqual(bodyAttempts, 2)
        XCTAssertEqual(log.paths.filter { $0 == bodyPath }.count, 2)
        XCTAssertFalse(log.paths.contains { $0.hasSuffix("/body") == false && $0.contains(noteID.uuidString.lowercased()) && $0 == "/v1/notes/\(noteID.uuidString.lowercased())" })
        let noteGETPaths = log.paths.filter {
            $0 == "/v1/notes/\(noteID.uuidString.lowercased())"
        }
        XCTAssertTrue(noteGETPaths.isEmpty)

        let row = try await indexStore.fetchNote(noteID: noteID)
        XCTAssertEqual(row?.syncState, .synced)
        XCTAssertEqual(row?.etag, #"W/"retry-body-etag""#)
        let local = try await localRepository.readNote(noteID: noteID)
        XCTAssertEqual(local.metadata.title, "Local wins")
    }

    func testFlushResumesAttachmentUploadSessionKeyedByNoteAndAttachment() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440075")!
        let attachmentID = UUID(uuidString: "880e8400-e29b-41d4-a716-446655440075")!
        let uploadID = NoteFixtures.uploadID
        let chunkSize = 5_000_000
        let ciphertext = Data(repeating: 0xAA, count: NoteUploadSizeThreshold + 1)
        let log = RequestLog()
        let (indexStore, localRepository, _, _, syncService) = makeSyncEnvironment()

        let bodyPath = "/v1/notes/\(noteID.uuidString.lowercased())/body"
        let initPath =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())/uploads"
        let manifestPath = "/v1/notes/\(noteID.uuidString.lowercased())/attachments"

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            if let response = NoteFixtures.pullCatalogGETResponse(for: request) {
                return response
            }
            let path = request.url!.path

            if path == bodyPath {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, NoteFixtures.writeNoteResponseJSON())
            }
            if path == manifestPath && request.httpMethod == "GET" {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, NoteFixtures.attachmentsManifestJSON(attachments: []))
            }
            if path == initPath {
                XCTFail("Should resume existing attachment upload session")
                return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
            }
            if path.contains("/chunks/") {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 204)
                return (response, nil)
            }
            if path.hasSuffix("/complete") {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, NoteFixtures.writeAttachmentResponseJSON(noteEtag: #"W/"complete-etag""#))
            }
            XCTFail("Unexpected path: \(path)")
            return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
        }

        try await NoteTestSupport.openIndexStore(indexStore)
        try await localRepository.writeNote(
            makeNote(
                noteID: noteID,
                title: "Resume attachment",
                attachmentID: attachmentID,
                ciphertext: ciphertext
            )
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
        XCTAssertTrue(
            log.paths.contains {
                $0.contains(attachmentID.uuidString.lowercased()) && $0.contains(uploadID.uuidString.lowercased())
            }
        )

        let session = try await indexStore.fetchAttachmentUploadSession(
            noteID: noteID,
            attachmentID: attachmentID
        )
        XCTAssertNil(session)

        let row = try await indexStore.fetchNote(noteID: noteID)
        XCTAssertEqual(row?.syncState, .synced)
        XCTAssertEqual(row?.etag, #"W/"abc123""#)
    }

    private func makeNote(
        noteID: UUID,
        title: String,
        attachmentID: UUID,
        ciphertext: Data
    ) -> StoredNote {
        StoredNote(
            metadata: NoteMetadata(
                noteID: noteID,
                title: title,
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
