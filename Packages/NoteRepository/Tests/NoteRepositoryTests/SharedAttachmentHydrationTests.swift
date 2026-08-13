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
        try await seedSharedNoteShell(noteID: noteID, indexStore: indexStore)

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

        let storedCiphertext = try await localRepository.readSharedAttachmentCiphertext(
            noteID: noteID,
            attachmentID: attachmentID
        )
        XCTAssertEqual(storedCiphertext, ciphertext)
        let sharedAttachmentURL = temporaryDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("shared", isDirectory: true)
            .appendingPathComponent(noteID.uuidString, isDirectory: true)
            .appendingPathComponent("attachments", isDirectory: true)
            .appendingPathComponent(attachmentID.uuidString)
        let ownedAttachmentURL = temporaryDirectory
            .appendingPathComponent(noteID.uuidString, isDirectory: true)
            .appendingPathComponent("attachments", isDirectory: true)
            .appendingPathComponent(attachmentID.uuidString)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sharedAttachmentURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: ownedAttachmentURL.path))
        XCTAssertTrue(log.paths.contains(sharedManifestPath))
        XCTAssertFalse(log.paths.contains { $0.hasPrefix(ownedAttachmentPrefix) })
    }

    func testRetrySharedAttachmentUsesSharedPath() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-4466554400a1")!
        let attachmentID = UUID(uuidString: "880e8400-e29b-41d4-a716-4466554400a1")!
        let ciphertext = Data(repeating: 0x99, count: 18)
        let (indexStore, localRepository, syncService) = makeSyncEnvironment()
        try await NoteTestSupport.openIndexStore(indexStore)
        try await seedSharedNoteShell(noteID: noteID, indexStore: indexStore)

        let sharedManifestPath = "/v1/notes/shared/\(noteID.uuidString.lowercased())/attachments"
        let sharedAttachmentPath =
            "/v1/notes/shared/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())/chunks/0"
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
                return (response, ciphertext)
            }
            XCTFail("Unexpected path: \(path)")
            return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
        }

        await syncService.retrySharedAttachment(noteID: noteID, attachmentID: attachmentID)

        let storedCiphertext = try await localRepository.readSharedAttachmentCiphertext(
            noteID: noteID,
            attachmentID: attachmentID
        )
        XCTAssertEqual(storedCiphertext, ciphertext)
        XCTAssertTrue(log.paths.contains(sharedManifestPath))
        XCTAssertTrue(log.paths.contains(sharedAttachmentPath))
    }

    private func seedSharedNoteShell(noteID: UUID, indexStore: NotesIndexStore) async throws {
        try await indexStore.upsertSharedNote(
            SharedNoteIndexRow(
                summary: SharedNoteSummary(
                    noteID: noteID,
                    title: "Shared",
                    updatedAt: 1_700_000_100,
                    etag: #"W/"shared-etag""#,
                    ownerEmail: "owner@example.com",
                    ownerID: UUID(uuidString: "660e8400-e29b-41d4-a716-446655440000")!,
                    sharedAt: Date(timeIntervalSince1970: 1_700_000_100)
                ),
                bodyEtag: #"W/"shared-etag""#
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
