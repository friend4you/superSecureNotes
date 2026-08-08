import Foundation
import NoteRepositoryProtocol
import SecureCrypto
import VaultRepository
import XCTest

@testable import NoteRepository

final class AttachmentHydrationTests: XCTestCase {
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

    func testHydrateAttachmentsDownloadsMissingFiles() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440080")!
        let attachmentID1 = UUID(uuidString: "880e8400-e29b-41d4-a716-446655440080")!
        let attachmentID2 = UUID(uuidString: "880e8400-e29b-41d4-a716-446655440081")!
        let ciphertext1 = Data(repeating: 0x11, count: 32)
        let ciphertext2 = Data(repeating: 0x22, count: 48)

        let (indexStore, localRepository, syncService) = makeSyncEnvironment()
        try await NoteTestSupport.openIndexStore(indexStore)
        try await seedBodyOnlyNote(noteID: noteID, repository: localRepository)

        let manifestPath = "/v1/notes/\(noteID.uuidString.lowercased())/attachments"
        let attachmentPath1 =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID1.uuidString.lowercased())"
        let attachmentPath2 =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID2.uuidString.lowercased())"
        let log = RequestLog()

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let path = request.url!.path
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            if path == manifestPath && request.httpMethod == "GET" {
                return (
                    response,
                    NoteFixtures.attachmentsManifestJSON(attachments: [
                        (attachmentID1, UInt64(ciphertext1.count), "application/octet-stream", #"W/"a1""#),
                        (attachmentID2, UInt64(ciphertext2.count), "application/octet-stream", #"W/"a2""#),
                    ])
                )
            }
            if path == attachmentPath1 {
                return (response, ciphertext1)
            }
            if path == attachmentPath2 {
                return (response, ciphertext2)
            }
            XCTFail("Unexpected path: \(path)")
            return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
        }

        await syncService.hydrateAttachments(noteID: noteID)

        let note = try await localRepository.readNote(noteID: noteID)
        XCTAssertEqual(note.attachmentCiphertexts[attachmentID1], ciphertext1)
        XCTAssertEqual(note.attachmentCiphertexts[attachmentID2], ciphertext2)
        XCTAssertTrue(log.paths.contains(manifestPath))
        XCTAssertTrue(log.paths.contains(attachmentPath1))
        XCTAssertTrue(log.paths.contains(attachmentPath2))
    }

    func testHydrateAttachmentsCapsConcurrencyAtThree() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440082")!
        let attachmentIDs = (0 ..< 4).map { index in
            UUID(uuidString: "880e8400-e29b-41d4-a716-44665544008\(index)")!
        }
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
        try await NoteTestSupport.openIndexStore(indexStore)
        try await seedBodyOnlyNote(noteID: noteID, repository: localRepository)

        let probe = AsyncConcurrencyProbe(holdCount: 3)
        let remote = HydrationRemoteStub(
            attachments: attachmentIDs.map {
                RemoteAttachmentSummary(
                    attachmentID: $0,
                    sizeBytes: 16,
                    contentType: "application/octet-stream",
                    etag: #"W/"x""#
                )
            },
            probe: probe
        )
        let syncService = LocalFirstNoteSyncService(
            localNotes: localRepository,
            remoteNotes: remote,
            localVault: localVault,
            remoteVault: remoteVault
        )

        let hydrateTask = Task {
            await syncService.hydrateAttachments(noteID: noteID)
        }

        let reachedThree = await probe.waitUntilMaxInFlight(atLeast: 3, timeout: 2.0)
        XCTAssertTrue(reachedThree)
        let maxDuringHold = await probe.maxInFlight
        let inFlightDuringHold = await probe.inFlight
        XCTAssertEqual(maxDuringHold, 3)
        XCTAssertLessThanOrEqual(inFlightDuringHold, 3)

        await probe.releaseHeld()
        await hydrateTask.value

        let note = try await localRepository.readNote(noteID: noteID)
        XCTAssertEqual(note.attachmentCiphertexts.count, 4)
        let maxAfter = await probe.maxInFlight
        XCTAssertEqual(maxAfter, 3)
    }

    func testHydrateAttachmentsContinuesAfterCallerCancelled() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440083")!
        let attachmentID = UUID(uuidString: "880e8400-e29b-41d4-a716-446655440083")!
        let ciphertext = Data(repeating: 0x33, count: 24)
        let (indexStore, localRepository, syncService) = makeSyncEnvironment()
        try await NoteTestSupport.openIndexStore(indexStore)
        try await seedBodyOnlyNote(noteID: noteID, repository: localRepository)

        let manifestPath = "/v1/notes/\(noteID.uuidString.lowercased())/attachments"
        let attachmentPath =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())"
        let gate = DownloadHoldGate()

        URLProtocolStub.requestHandler = { request in
            let path = request.url!.path
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            if path == manifestPath && request.httpMethod == "GET" {
                return (
                    response,
                    NoteFixtures.attachmentsManifestJSON(attachments: [
                        (attachmentID, UInt64(ciphertext.count), "application/octet-stream", #"W/"a""#),
                    ])
                )
            }
            if path == attachmentPath {
                gate.markStarted()
                gate.waitForRelease()
                return (response, ciphertext)
            }
            XCTFail("Unexpected path: \(path)")
            return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
        }

        let caller = Task {
            await syncService.hydrateAttachments(noteID: noteID)
        }

        XCTAssertTrue(gate.waitUntilStarted(timeout: 2.0))
        caller.cancel()
        gate.release()
        _ = await caller.result

        let note = try await localRepository.readNote(noteID: noteID)
        XCTAssertEqual(note.attachmentCiphertexts[attachmentID], ciphertext)
    }

    func testWarmLocalOpenSkipsHydrationDownloads() async throws {
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440084")!
        let attachmentID = UUID(uuidString: "880e8400-e29b-41d4-a716-446655440084")!
        let ciphertext = Data(repeating: 0x44, count: 20)
        let (indexStore, localRepository, syncService) = makeSyncEnvironment()
        try await NoteTestSupport.openIndexStore(indexStore)

        try await localRepository.writeNote(
            StoredNote(
                metadata: NoteMetadata(
                    noteID: noteID,
                    title: "Warm",
                    createdAt: 1_700_000_000,
                    updatedAt: 1_700_000_100,
                    attachmentCount: 1,
                    attachmentsTotalSize: UInt64(ciphertext.count)
                ),
                wrappedFEK: Data(repeating: 0xAB, count: 60),
                encryptedPayload: Data(repeating: 0xCD, count: 128),
                syncState: .synced,
                attachmentCiphertexts: [attachmentID: ciphertext]
            )
        )

        let log = RequestLog()
        URLProtocolStub.requestHandler = { request in
            log.record(request)
            return (TestHTTP.makeResponse(url: request.url!, statusCode: 200), Data("[]".utf8))
        }

        await syncService.hydrateAttachments(noteID: noteID)

        XCTAssertTrue(log.paths.isEmpty)
        let note = try await localRepository.readNote(noteID: noteID)
        XCTAssertEqual(note.attachmentCiphertexts[attachmentID], ciphertext)
    }

    private func seedBodyOnlyNote(noteID: UUID, repository: LocalNoteRepository) async throws {
        try await repository.writeNote(
            StoredNote(
                metadata: NoteMetadata(
                    noteID: noteID,
                    title: "Cold",
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

private actor AsyncConcurrencyProbe {
    private let holdCount: Int
    private var held = 0
    private(set) var inFlight = 0
    private(set) var maxInFlight = 0
    private var holdWaiters: [CheckedContinuation<Void, Never>] = []
    private var maxWaiters: [UUID: (target: Int, continuation: CheckedContinuation<Bool, Never>)] = [:]

    init(holdCount: Int) {
        self.holdCount = holdCount
    }

    func enter() async {
        inFlight += 1
        maxInFlight = max(maxInFlight, inFlight)
        let shouldHold = held < holdCount
        if shouldHold {
            held += 1
        }
        resumeMaxWaitersIfReady()

        if shouldHold {
            await withCheckedContinuation { continuation in
                holdWaiters.append(continuation)
            }
        }
    }

    func leave() {
        inFlight -= 1
    }

    func releaseHeld() {
        let pending = holdWaiters
        holdWaiters.removeAll()
        for waiter in pending {
            waiter.resume()
        }
    }

    func waitUntilMaxInFlight(atLeast target: Int, timeout: TimeInterval) async -> Bool {
        if maxInFlight >= target {
            return true
        }
        let id = UUID()
        return await withCheckedContinuation { continuation in
            maxWaiters[id] = (target, continuation)
            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                self.timeoutMaxWaiter(id: id)
            }
        }
    }

    private func resumeMaxWaitersIfReady() {
        for (id, waiter) in maxWaiters {
            if maxInFlight >= waiter.target {
                maxWaiters.removeValue(forKey: id)
                waiter.continuation.resume(returning: true)
            }
        }
    }

    private func timeoutMaxWaiter(id: UUID) {
        guard let waiter = maxWaiters.removeValue(forKey: id) else {
            return
        }
        waiter.continuation.resume(returning: maxInFlight >= waiter.target)
    }
}

private actor HydrationRemoteStub: NoteSyncRemoteStoring {
    private let attachments: [RemoteAttachmentSummary]
    private let probe: AsyncConcurrencyProbe

    init(attachments: [RemoteAttachmentSummary], probe: AsyncConcurrencyProbe) {
        self.attachments = attachments
        self.probe = probe
    }

    func listNotes(includeDeleted: Bool) async throws -> [NoteSummary] { [] }

    func uploadNote(
        _ note: StoredNote,
        ifMatch etag: String?,
        uploadSessionStore: (any AttachmentUploadSessionStoring)?
    ) async throws -> NoteUploadResult {
        NoteUploadResult(syncState: .synced, updatedAt: 0, etag: etag)
    }

    func readNote(noteID: UUID) async throws -> StoredNote {
        throw NoteRepositoryError.noteNotFound
    }

    func deleteNote(noteID: UUID) async throws {}

    func listAttachments(noteID: UUID) async throws -> [RemoteAttachmentSummary] {
        _ = noteID
        return attachments
    }

    func readAttachment(noteID: UUID, attachmentID: UUID) async throws -> Data {
        _ = noteID
        _ = attachmentID
        await probe.enter()
        await probe.leave()
        return Data(repeating: 0xAB, count: 16)
    }

    func listSharedAttachments(noteID: UUID) async throws -> [RemoteAttachmentSummary] {
        try await listAttachments(noteID: noteID)
    }

    func readSharedAttachment(noteID: UUID, attachmentID: UUID) async throws -> Data {
        try await readAttachment(noteID: noteID, attachmentID: attachmentID)
    }
}

private final class DownloadHoldGate: @unchecked Sendable {
    private let lock = NSLock()
    private let startedCondition = NSCondition()
    private let holdSemaphore = DispatchSemaphore(value: 0)
    private var started = false

    func markStarted() {
        startedCondition.lock()
        started = true
        startedCondition.broadcast()
        startedCondition.unlock()
    }

    func waitUntilStarted(timeout: TimeInterval) -> Bool {
        startedCondition.lock()
        defer { startedCondition.unlock() }
        if started { return true }
        let deadline = Date().addingTimeInterval(timeout)
        while !started {
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else { return started }
            _ = startedCondition.wait(until: deadline)
        }
        return started
    }

    func waitForRelease() {
        holdSemaphore.wait()
    }

    func release() {
        holdSemaphore.signal()
    }
}
