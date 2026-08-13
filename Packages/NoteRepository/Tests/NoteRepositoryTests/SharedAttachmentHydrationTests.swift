import Foundation
import NoteRepositoryProtocol
import SecureCrypto
import VaultRepository
import XCTest

@testable import NoteRepository

final class SharedAttachmentHydrationTests: XCTestCase {
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

    func testHydrateSharedAttachmentsUsesSharedEndpoints() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-4466554400a0")!
        let attachmentID = UUID(uuidString: "880e8400-e29b-41d4-a716-4466554400a0")!
        let ciphertext = Data(repeating: 0x88, count: 28)
        let (indexStore, localRepository, syncService) = makeSyncEnvironment()
        try await NoteTestSupport.openIndexStore(indexStore)
        try await seedBodyOnlyNote(noteID: noteID, repository: localRepository)

        let sharedManifestPath = "/v1/notes/shared/\(noteID.uuidString.lowercased())/attachments"
        let sharedAttachmentPath =
            "/v1/notes/shared/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())/chunks/0"
        let ownedAttachmentPrefix = "/v1/notes/\(noteID.uuidString.lowercased())/attachments"
        let log = RequestLog()

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let path = request.url!.path
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            if path == sharedManifestPath && request.httpMethod == "GET" {
                return (
                    response,
                    NoteFixtures.attachmentsManifestJSON(attachments: [
                        (attachmentID, UInt64(ciphertext.count), "application/octet-stream", #"W/"shared""#),
                    ])
                )
            }
            if path == sharedAttachmentPath {
                return (response, ciphertext)
            }
            XCTFail("Unexpected path: \(path)")
            return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
        }

        await syncService.hydrateSharedAttachments(noteID: noteID)

        let note = try await localRepository.readNote(noteID: noteID)
        XCTAssertEqual(note.attachmentCiphertexts[attachmentID], ciphertext)
        XCTAssertTrue(log.paths.contains(sharedManifestPath))
        XCTAssertTrue(log.paths.contains(sharedAttachmentPath))
        XCTAssertFalse(log.paths.contains { $0.hasPrefix(ownedAttachmentPrefix) })
    }

    func testRetrySharedAttachmentUsesSharedPath() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-4466554400a1")!
        let attachmentID = UUID(uuidString: "880e8400-e29b-41d4-a716-4466554400a1")!
        let ciphertext = Data(repeating: 0x99, count: 18)
        let (indexStore, localRepository, syncService) = makeSyncEnvironment()
        try await NoteTestSupport.openIndexStore(indexStore)
        try await seedBodyOnlyNote(noteID: noteID, repository: localRepository)

        let sharedManifestPath = "/v1/notes/shared/\(noteID.uuidString.lowercased())/attachments"
        let sharedAttachmentPath =
            "/v1/notes/shared/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())/chunks/0"
        let failState = FailOnceSharedState()
        let log = RequestLog()

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let path = request.url!.path
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            if path == sharedManifestPath && request.httpMethod == "GET" {
                return (
                    response,
                    NoteFixtures.attachmentsManifestJSON(attachments: [
                        (attachmentID, UInt64(ciphertext.count), "application/octet-stream", #"W/"shared-retry""#),
                    ])
                )
            }
            if path == sharedAttachmentPath {
                if failState.shouldFail() {
                    return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
                }
                return (response, ciphertext)
            }
            XCTFail("Unexpected path: \(path)")
            return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
        }

        await syncService.hydrateSharedAttachments(noteID: noteID)
        let afterFailedHydration = try await localRepository.readNote(noteID: noteID)
        XCTAssertNil(afterFailedHydration.attachmentCiphertexts[attachmentID])

        await syncService.retrySharedAttachment(noteID: noteID, attachmentID: attachmentID)

        let note = try await localRepository.readNote(noteID: noteID)
        XCTAssertEqual(note.attachmentCiphertexts[attachmentID], ciphertext)
        XCTAssertEqual(log.paths.filter { $0 == sharedAttachmentPath }.count, 2)
    }

    private func seedBodyOnlyNote(noteID: UUID, repository: LocalNoteRepository) async throws {
        try await repository.writeNote(
            StoredNote(
                metadata: NoteMetadata(
                    noteID: noteID,
                    title: "Shared",
                    createdAt: 1_700_000_000,
                    updatedAt: 1_700_000_100,
                    attachmentCount: 0,
                    attachmentsTotalSize: 0
                ),
                wrappedFEK: Data(repeating: 0xAB, count: 60),
                encryptedPayload: Data(repeating: 0xCD, count: 128),
                syncState: .synced,
                attachmentCiphertexts: [:]
            )
        )
    }

    private func makeSyncEnvironment() -> (
        NotesIndexStore,
        LocalNoteRepository,
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
            remoteNotes: NetworkNoteRepository(
                baseURL: NoteFixtures.baseURL,
                tokenProvider: MockTokenProvider(),
                session: .stubbed()
            ),
            localVault: localVault,
            remoteVault: remoteVault
        )
        return (indexStore, localRepository, syncService)
    }
}

private final class FailOnceSharedState: @unchecked Sendable {
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
