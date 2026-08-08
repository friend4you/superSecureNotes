import NoteRepositoryProtocol
import SecureCrypto
import VaultRepository
import XCTest

@testable import NoteRepository

final class LocalFirstNoteSyncServiceSplitUploadTests: XCTestCase {
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

    func testFlushKeepsPendingSyncUntilAllAttachmentsSucceed() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440070")!
        let attachmentID1 = UUID(uuidString: "880e8400-e29b-41d4-a716-446655440070")!
        let attachmentID2 = UUID(uuidString: "880e8400-e29b-41d4-a716-446655440071")!
        let (indexStore, localRepository, _, _, syncService) = makeSyncEnvironment()
        let log = RequestLog()
        let failState = FailOnceState()

        let bodyPath = "/v1/notes/\(noteID.uuidString.lowercased())/body"
        let attachmentPath1 =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID1.uuidString.lowercased())"
        let attachmentPath2 =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID2.uuidString.lowercased())"
        let manifestPath = "/v1/notes/\(noteID.uuidString.lowercased())/attachments"

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            if let response = NoteFixtures.pullCatalogGETResponse(for: request) {
                return response
            }
            let path = request.url!.path
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)

            if path == bodyPath {
                return (response, NoteFixtures.writeNoteResponseJSON(etag: #"W/"body-etag""#))
            }
            if path == manifestPath && request.httpMethod == "GET" {
                return (response, NoteFixtures.attachmentsManifestJSON(attachments: []))
            }
            if path == attachmentPath1 {
                return (response, NoteFixtures.writeAttachmentResponseJSON(noteEtag: #"W/"note-etag-1""#))
            }
            if path == attachmentPath2 {
                if failState.shouldFail() {
                    return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
                }
                return (response, NoteFixtures.writeAttachmentResponseJSON(noteEtag: #"W/"note-etag-2""#))
            }
            XCTFail("Unexpected path: \(path)")
            return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
        }

        try await NoteTestSupport.openIndexStore(indexStore)
        try await localRepository.writeNote(
            makeNoteWithAttachments(
                noteID: noteID,
                title: "Partial upload",
                ciphertexts: [
                    attachmentID1: Data(repeating: 0x11, count: 16),
                    attachmentID2: Data(repeating: 0x22, count: 24),
                ]
            )
        )

        let failedOutcomeTask = Task {
            var iterator = syncService.syncOutcomes.makeAsyncIterator()
            return await iterator.next()
        }

        await syncService.flushPending()

        let failedOutcome = await failedOutcomeTask.value
        XCTAssertEqual(failedOutcome, .uploadFailed(noteID: noteID))

        var row = try await indexStore.fetchNote(noteID: noteID)
        XCTAssertEqual(row?.syncState, .pendingSync)
        XCTAssertFalse(log.paths.contains(bodyPath))
        XCTAssertTrue(log.paths.contains(attachmentPath1))
        XCTAssertTrue(log.paths.contains(attachmentPath2))

        let successOutcomeTask = Task {
            var iterator = syncService.syncOutcomes.makeAsyncIterator()
            return await iterator.next()
        }

        await syncService.flushPending()

        let successOutcome = await successOutcomeTask.value
        XCTAssertEqual(
            successOutcome,
            .uploaded(
                noteID: noteID,
                syncState: .synced,
                updatedAt: 1_700_000_100,
                etag: #"W/"body-etag""#
            )
        )

        row = try await indexStore.fetchNote(noteID: noteID)
        XCTAssertEqual(row?.syncState, .synced)
        XCTAssertEqual(row?.etag, #"W/"body-etag""#)
    }

    func testFlushReconcilesAttachmentsBeforeBodyAndEmitsOutcome() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440072")!
        let attachmentID = UUID(uuidString: "880e8400-e29b-41d4-a716-446655440072")!
        let removedID = UUID(uuidString: "880e8400-e29b-41d4-a716-446655440073")!
        let (indexStore, localRepository, _, _, syncService) = makeSyncEnvironment()
        let log = RequestLog()

        let bodyPath = "/v1/notes/\(noteID.uuidString.lowercased())/body"
        let attachmentPath =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())"
        let removedPath =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(removedID.uuidString.lowercased())"
        let manifestPath = "/v1/notes/\(noteID.uuidString.lowercased())/attachments"

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            if let response = NoteFixtures.pullCatalogGETResponse(for: request) {
                return response
            }
            let path = request.url!.path

            if path == bodyPath {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, NoteFixtures.writeNoteResponseJSON(etag: #"W/"body-etag""#))
            }
            if path == manifestPath && request.httpMethod == "GET" {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (
                    response,
                    NoteFixtures.attachmentsManifestJSON(
                        attachments: [
                            (
                                attachmentID: removedID,
                                sizeBytes: 8,
                                contentType: "application/octet-stream",
                                etag: #"W/"old""#
                            ),
                        ]
                    )
                )
            }
            if path == attachmentPath && request.httpMethod == "PUT" {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, NoteFixtures.writeAttachmentResponseJSON(noteEtag: #"W/"final-etag""#))
            }
            if path == removedPath && request.httpMethod == "DELETE" {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 204)
                return (response, nil)
            }
            XCTFail("Unexpected \(request.httpMethod ?? "") \(path)")
            return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
        }

        try await NoteTestSupport.openIndexStore(indexStore)
        try await localRepository.writeNote(
            makeNoteWithAttachments(
                noteID: noteID,
                title: "Split flush",
                ciphertexts: [attachmentID: Data(repeating: 0xAA, count: 32)]
            )
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
                updatedAt: 1_700_000_100,
                etag: #"W/"body-etag""#
            )
        )

        XCTAssertEqual(log.method(at: 0), "GET")
        XCTAssertEqual(log.path(at: 0), manifestPath)
        XCTAssertTrue(log.paths.contains(attachmentPath))
        XCTAssertTrue(log.paths.contains(removedPath))
        let bodyIndex = try XCTUnwrap(log.paths.firstIndex(of: bodyPath))
        let attachmentIndex = try XCTUnwrap(log.paths.firstIndex(of: attachmentPath))
        let deleteIndex = try XCTUnwrap(log.paths.firstIndex(of: removedPath))
        XCTAssertLessThan(deleteIndex, attachmentIndex)
        XCTAssertLessThan(attachmentIndex, bodyIndex)
        XCTAssertTrue(log.paths.contains(bodyPath))

        let row = try await indexStore.fetchNote(noteID: noteID)
        XCTAssertEqual(row?.syncState, .synced)
        XCTAssertEqual(row?.etag, #"W/"body-etag""#)
    }

    private func makeNoteWithAttachments(
        noteID: UUID,
        title: String,
        ciphertexts: [UUID: Data]
    ) -> StoredNote {
        let totalSize = ciphertexts.values.reduce(0) { $0 + UInt64($1.count) }
        return StoredNote(
            metadata: NoteMetadata(
                noteID: noteID,
                title: title,
                createdAt: 1_700_000_000,
                updatedAt: 1_700_000_100,
                attachmentCount: UInt32(ciphertexts.count),
                attachmentsTotalSize: totalSize
            ),
            wrappedFEK: Data(repeating: 0xAB, count: 60),
            encryptedPayload: Data(repeating: 0xCD, count: 128),
            syncState: .pendingSync,
            attachmentCiphertexts: ciphertexts
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

private final class FailOnceState: @unchecked Sendable {
    private let lock = NSLock()
    private var failed = false

    func shouldFail() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if failed {
            return false
        }
        failed = true
        return true
    }
}
