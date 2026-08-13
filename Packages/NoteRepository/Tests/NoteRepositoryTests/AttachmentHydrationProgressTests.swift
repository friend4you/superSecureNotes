import Foundation
import NoteRepositoryProtocol
import SecureCrypto
import VaultRepository
import XCTest

@testable import NoteRepository

final class AttachmentHydrationProgressTests: XCTestCase {
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

    func testProgressStreamEmitsPerAttachmentBytesReceivedOverTotal() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440090")!
        let attachmentID = UUID(uuidString: "880e8400-e29b-41d4-a716-446655440090")!
        let ciphertext = Data(repeating: 0x55, count: 64)
        let (indexStore, localRepository, syncService) = makeSyncEnvironment()
        try await NoteTestSupport.openIndexStore(indexStore)
        try await seedBodyOnlyNote(noteID: noteID, repository: localRepository)

        let manifestPath = "/v1/notes/\(noteID.uuidString.lowercased())/attachments"
        let attachmentPath =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())/chunks/0"

        URLProtocolStub.requestHandler = { request in
            let path = request.url!.path
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            if path == manifestPath && request.httpMethod == "GET" {
                return (
                    response,
                    NoteFixtures.attachmentsManifestJSON(attachments: [
                        (attachmentID, UInt64(ciphertext.count), "application/octet-stream", #"W/"p""#),
                    ])
                )
            }
            if path == attachmentPath {
                return (response, ciphertext)
            }
            XCTFail("Unexpected path: \(path)")
            return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
        }

        let progressTask = Task<[AttachmentHydrationProgress], Never> {
            var collected: [AttachmentHydrationProgress] = []
            for await progress in syncService.attachmentHydrationProgress {
                guard progress.noteID == noteID, progress.attachmentID == attachmentID else {
                    continue
                }
                collected.append(progress)
                if progress.state == .completed || progress.state == .failed {
                    break
                }
            }
            return collected
        }

        // Allow subscriber to attach before hydration starts.
        try await Task.sleep(nanoseconds: 20_000_000)
        await syncService.hydrateAttachments(noteID: noteID)

        let events = await progressTask.value
        XCTAssertFalse(events.isEmpty)
        XCTAssertEqual(events.first?.bytesReceived, 0)
        XCTAssertEqual(events.first?.totalBytes, UInt64(ciphertext.count))
        XCTAssertEqual(events.first?.state, .downloading)
        XCTAssertEqual(events.last?.bytesReceived, UInt64(ciphertext.count))
        XCTAssertEqual(events.last?.totalBytes, UInt64(ciphertext.count))
        XCTAssertEqual(events.last?.state, .completed)
    }

    func testProgressIncrementsAsEachChunkCompletes() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440093")!
        let attachmentID = UUID(uuidString: "880e8400-e29b-41d4-a716-446655440093")!
        let chunk0 = Data(repeating: 0x01, count: 4)
        let chunk1 = Data(repeating: 0x02, count: 4)
        let chunk2 = Data(repeating: 0x03, count: 4)
        let ciphertext = chunk0 + chunk1 + chunk2
        let (indexStore, localRepository, syncService) = makeSyncEnvironment()
        try await NoteTestSupport.openIndexStore(indexStore)
        try await seedBodyOnlyNote(noteID: noteID, repository: localRepository)

        let manifestPath = "/v1/notes/\(noteID.uuidString.lowercased())/attachments"
        let base =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())"

        URLProtocolStub.requestHandler = { request in
            let path = request.url!.path
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            if path == manifestPath && request.httpMethod == "GET" {
                return (
                    response,
                    NoteFixtures.attachmentsManifestJSON(attachments: [
                        (
                            attachmentID: attachmentID,
                            sizeBytes: UInt64(ciphertext.count),
                            contentType: "application/octet-stream",
                            etag: #"W/"chunks""#,
                            totalChunks: 3,
                            chunkSize: 4
                        ),
                    ])
                )
            }
            if path == "\(base)/chunks/0" {
                return (response, chunk0)
            }
            if path == "\(base)/chunks/1" {
                return (response, chunk1)
            }
            if path == "\(base)/chunks/2" {
                return (response, chunk2)
            }
            XCTFail("Unexpected path: \(path)")
            return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
        }

        let progressTask = Task<[AttachmentHydrationProgress], Never> {
            var collected: [AttachmentHydrationProgress] = []
            for await progress in syncService.attachmentHydrationProgress {
                guard progress.noteID == noteID, progress.attachmentID == attachmentID else {
                    continue
                }
                collected.append(progress)
                if progress.state == .completed || progress.state == .failed {
                    break
                }
            }
            return collected
        }

        try await Task.sleep(nanoseconds: 20_000_000)
        await syncService.hydrateAttachments(noteID: noteID)

        let events = await progressTask.value
        let downloading = events.filter { $0.state == .downloading }
        XCTAssertGreaterThanOrEqual(downloading.count, 4) // 0 + 3 chunk increments
        XCTAssertEqual(downloading.first?.bytesReceived, 0)
        XCTAssertTrue(downloading.contains { $0.bytesReceived == 4 })
        XCTAssertTrue(downloading.contains { $0.bytesReceived == 8 })
        XCTAssertTrue(downloading.contains { $0.bytesReceived == 12 })
        XCTAssertEqual(events.last?.state, .completed)
        XCTAssertEqual(events.last?.bytesReceived, UInt64(ciphertext.count))

        let note = try await localRepository.readNote(noteID: noteID)
        XCTAssertEqual(note.attachmentCiphertexts[attachmentID], ciphertext)
    }

    func testRetryAttachmentDownloadsOnlyFailedId() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440091")!
        let okID = UUID(uuidString: "880e8400-e29b-41d4-a716-446655440091")!
        let failID = UUID(uuidString: "880e8400-e29b-41d4-a716-446655440092")!
        let okCiphertext = Data(repeating: 0x66, count: 16)
        let failCiphertext = Data(repeating: 0x77, count: 20)
        let (indexStore, localRepository, syncService) = makeSyncEnvironment()
        try await NoteTestSupport.openIndexStore(indexStore)
        try await seedBodyOnlyNote(noteID: noteID, repository: localRepository)

        let manifestPath = "/v1/notes/\(noteID.uuidString.lowercased())/attachments"
        let okPath =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(okID.uuidString.lowercased())/chunks/0"
        let failPath =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(failID.uuidString.lowercased())/chunks/0"
        let failState = FailOnceState()
        let log = RequestLog()

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let path = request.url!.path
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            if path == manifestPath && request.httpMethod == "GET" {
                return (
                    response,
                    NoteFixtures.attachmentsManifestJSON(attachments: [
                        (okID, UInt64(okCiphertext.count), "application/octet-stream", #"W/"ok""#),
                        (failID, UInt64(failCiphertext.count), "application/octet-stream", #"W/"fail""#),
                    ])
                )
            }
            if path == okPath {
                return (response, okCiphertext)
            }
            if path == failPath {
                if failState.shouldFail() {
                    return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
                }
                return (response, failCiphertext)
            }
            XCTFail("Unexpected path: \(path)")
            return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
        }

        await syncService.hydrateAttachments(noteID: noteID)

        var note = try await localRepository.readNote(noteID: noteID)
        XCTAssertEqual(note.attachmentCiphertexts[okID], okCiphertext)
        XCTAssertNil(note.attachmentCiphertexts[failID])

        let downloadsBeforeRetry = log.paths.filter { $0 == failPath }.count
        XCTAssertEqual(downloadsBeforeRetry, 1)

        await syncService.retryAttachment(noteID: noteID, attachmentID: failID)

        note = try await localRepository.readNote(noteID: noteID)
        XCTAssertEqual(note.attachmentCiphertexts[okID], okCiphertext)
        XCTAssertEqual(note.attachmentCiphertexts[failID], failCiphertext)

        let failDownloads = log.paths.filter { $0 == failPath }
        let okDownloads = log.paths.filter { $0 == okPath }
        XCTAssertEqual(failDownloads.count, 2)
        XCTAssertEqual(okDownloads.count, 1)
    }

    private func seedBodyOnlyNote(noteID: UUID, repository: LocalNoteRepository) async throws {
        try await repository.writeNote(
            StoredNote(
                metadata: NoteMetadata(
                    noteID: noteID,
                    title: "Progress",
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
