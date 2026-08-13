import CryptoKit
import NoteRepositoryProtocol
import SecureCrypto
import VaultRepository
import XCTest

@testable import NoteRepository

final class LocalFirstNoteSyncServiceMigrationTests: XCTestCase {
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

    func testFlushMigratesV1NoteThenSplitUploads() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440076")!
        let udk = SymmetricKey(size: .bits256)
        let fek = generateSymmetricKey()
        let log = RequestLog()
        let plaintextAttachment = Data([0x89, 0x50, 0x4E, 0x47])

        let v1Payload = NotePayload(
            body: Data("legacy body".utf8),
            attachments: [
                NotePayload.Attachment(
                    id: "legacy-att-id",
                    filename: "photo.png",
                    mime: "image/png",
                    data: plaintextAttachment
                ),
            ]
        )
        let encryptedPayload = try encryptPayload(v1Payload, with: fek)
        let wrappedFEK = try wrapFEK(fek, with: udk)

        let (indexStore, localRepository, _, _, syncService) = makeSyncEnvironment(
            noteFEKProvider: { id in
                XCTAssertEqual(id, noteID)
                return fek
            }
        )

        let bodyPath = "/v1/notes/\(noteID.uuidString.lowercased())/body"
        let manifestPath = "/v1/notes/\(noteID.uuidString.lowercased())/attachments"

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            if let response = NoteFixtures.pullCatalogGETResponse(for: request) {
                return response
            }
            let path = request.url!.path
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)

            if path == bodyPath {
                return (response, NoteFixtures.writeNoteResponseJSON(etag: #"W/"migrated-body""#))
            }
            if path == manifestPath && request.httpMethod == "GET" {
                return (response, NoteFixtures.attachmentsManifestJSON())
            }
            if let chunked = NoteFixtures.chunkedAttachmentUploadResponse(
                for: request,
                noteEtag: #"W/"migrated-note""#
            ) {
                return chunked
            }
            XCTFail("Unexpected \(request.httpMethod ?? "") \(path)")
            return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
        }

        try await NoteTestSupport.openIndexStore(indexStore)
        let v1Note = StoredNote(
            metadata: NoteMetadata(
                noteID: noteID,
                title: "V1 pending",
                createdAt: 1_700_000_000,
                updatedAt: 1_700_000_100,
                attachmentCount: 1,
                attachmentsTotalSize: UInt64(plaintextAttachment.count)
            ),
            wrappedFEK: wrappedFEK,
            encryptedPayload: encryptedPayload,
            syncState: .pendingSync
        )
        try await localRepository.writeNote(v1Note)

        let beforeFlush = try await localRepository.readNote(noteID: noteID)
        XCTAssertTrue(beforeFlush.attachmentCiphertexts.isEmpty)

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
                etag: #"W/"migrated-body""#
            )
        )

        let migrated = try await localRepository.readNote(noteID: noteID)
        XCTAssertEqual(migrated.syncState, .synced)
        XCTAssertEqual(migrated.attachmentCiphertexts.count, 1)

        let decrypted = try decryptPayload(migrated.encryptedPayload, with: fek)
        XCTAssertEqual(decrypted.schemaVersion, 2)
        XCTAssertEqual(decrypted.attachments.count, 1)
        XCTAssertNil(decrypted.attachments[0].data)
        XCTAssertNotEqual(decrypted.attachments[0].id, "legacy-att-id")

        let attachmentID = try XCTUnwrap(UUID(uuidString: decrypted.attachments[0].id))
        let attachmentUploadPath =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())/uploads"
        XCTAssertEqual(log.method(at: 0), "GET")
        XCTAssertTrue(log.paths.contains(attachmentUploadPath))
        XCTAssertTrue(log.paths.contains(bodyPath))
        XCTAssertFalse(log.paths.contains(where: NoteFixtures.isLegacyAttachmentBlobPath))

        let ciphertext = try XCTUnwrap(migrated.attachmentCiphertexts[attachmentID])
        XCTAssertEqual(try decryptAttachmentFile(ciphertext, with: fek), plaintextAttachment)
    }

    func testFlushSkipsMigrationWhenFEKProviderUnavailable() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440077")!
        let udk = SymmetricKey(size: .bits256)
        let fek = generateSymmetricKey()
        let log = RequestLog()

        let v1Payload = NotePayload(
            body: Data("legacy body".utf8),
            attachments: [
                NotePayload.Attachment(
                    id: "legacy-att-id",
                    filename: "photo.png",
                    mime: "image/png",
                    data: Data([0x01, 0x02])
                ),
            ]
        )
        let encryptedPayload = try encryptPayload(v1Payload, with: fek)
        let wrappedFEK = try wrapFEK(fek, with: udk)

        let (indexStore, localRepository, _, _, syncService) = makeSyncEnvironment(noteFEKProvider: nil)

        let bodyPath = "/v1/notes/\(noteID.uuidString.lowercased())/body"
        let manifestPath = "/v1/notes/\(noteID.uuidString.lowercased())/attachments"

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            if let response = NoteFixtures.pullCatalogGETResponse(for: request) {
                return response
            }
            let path = request.url!.path
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            if path == bodyPath {
                return (response, NoteFixtures.writeNoteResponseJSON())
            }
            if path == manifestPath && request.httpMethod == "GET" {
                return (response, NoteFixtures.attachmentsManifestJSON())
            }
            XCTFail("Unexpected attachment upload without migration: \(path)")
            return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
        }

        try await NoteTestSupport.openIndexStore(indexStore)
        try await localRepository.writeNote(
            StoredNote(
                metadata: NoteMetadata(
                    noteID: noteID,
                    title: "No FEK",
                    createdAt: 1_700_000_000,
                    updatedAt: 1_700_000_100,
                    attachmentCount: 1,
                    attachmentsTotalSize: 2
                ),
                wrappedFEK: wrappedFEK,
                encryptedPayload: encryptedPayload,
                syncState: .pendingSync
            )
        )

        await syncService.flushPending()

        let afterFlush = try await localRepository.readNote(noteID: noteID)
        XCTAssertTrue(afterFlush.attachmentCiphertexts.isEmpty)
        let decrypted = try decryptPayload(afterFlush.encryptedPayload, with: fek)
        XCTAssertEqual(decrypted.attachments[0].id, "legacy-att-id")
        XCTAssertNotNil(decrypted.attachments[0].data)

        XCTAssertEqual(log.paths.filter { $0.contains("/attachments/") && !$0.hasSuffix("/attachments") }.count, 0)
        let row = try await indexStore.fetchNote(noteID: noteID)
        XCTAssertEqual(row?.syncState, .synced)
    }

    private func makeRemoteRepository() -> NetworkNoteRepository {
        NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )
    }

    private func makeSyncEnvironment(
        noteFEKProvider: LocalFirstNoteSyncService.NoteFEKProvider?
    ) -> (
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
            remoteVault: remoteVault,
            noteFEKProvider: noteFEKProvider
        )
        return (indexStore, localRepository, localVault, remoteVault, syncService)
    }
}
