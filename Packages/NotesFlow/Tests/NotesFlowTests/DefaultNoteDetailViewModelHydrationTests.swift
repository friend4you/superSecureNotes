import CryptoKit
import NavigationProtocol
import NoteRepositoryProtocol
import NotesFlow
import SecureCrypto
import XCTest

@MainActor
private final class MockNavigating: Navigating {
    func setRoot<R: Route>(_ route: R) {}
    func push<R: Route>(_ route: R) {}
    func present<R: Route>(_ route: R, style: RoutePresentation) {}
    func pop() {}
    func popToRoot() {}
    func dismissPresentation() {}
}

@MainActor
final class DefaultNoteDetailViewModelHydrationTests: XCTestCase {
    func testLoadShowsBodyAndFilenamesBeforeHydrationCompletes() async throws {
        let noteID = UUID()
        let attachmentID = UUID()
        let udk = SymmetricKey(size: .bits256)
        let (noteData, _) = try NoteViewModelTestSupport.makeSplitStoredNote(
            noteID: noteID,
            title: "Cold open",
            body: "Visible immediately",
            udk: udk,
            attachmentPlaintexts: [
                (attachmentID, "photo.jpg", "image/jpeg", Data([0x01, 0x02, 0x03])),
            ],
            syncState: .synced
        )
        // Cold open: index present, ciphertext not yet local.
        let coldNote = StoredNote(
            metadata: noteData.metadata,
            wrappedFEK: noteData.wrappedFEK,
            encryptedPayload: noteData.encryptedPayload,
            syncState: .synced,
            attachmentCiphertexts: [:]
        )
        let noteRepository = StoredNoteMockRepository(notes: [noteID: coldNote])
        let noteSync = ControllableNoteSyncService()
        let hydrationStarted = expectation(description: "hydrateAttachments started")

        await noteSync.setHydrateAttachmentsHandler { id in
            XCTAssertEqual(id, noteID)
            hydrationStarted.fulfill()
            await noteSync.emitHydration(
                AttachmentHydrationProgress(
                    noteID: noteID,
                    attachmentID: attachmentID,
                    bytesReceived: 1,
                    totalBytes: 3,
                    state: .downloading
                )
            )
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        let viewModel = DefaultNoteDetailViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            vaultSession: StoredNoteMockVaultSession(udk: udk),
            navigator: MockNavigating(),
            noteSync: noteSync
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.title, "Cold open")
        XCTAssertEqual(viewModel.body, "Visible immediately")
        XCTAssertEqual(viewModel.attachmentItems.map(\.filename), ["photo.jpg"])
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.attachmentData(for: attachmentID.uuidString))

        await fulfillment(of: [hydrationStarted], timeout: 1.0)
        try? await Task.sleep(nanoseconds: 80_000_000)

        let progress = try XCTUnwrap(viewModel.attachmentProgressByID[attachmentID.uuidString])
        XCTAssertEqual(progress.state, .downloading)
        XCTAssertEqual(progress.bytesReceived, 1)
        XCTAssertEqual(progress.totalBytes, 3)

        let hydrateCount = await noteSync.hydrateAttachmentsCallCount
        XCTAssertEqual(hydrateCount, 1)
    }

    func testHydrationCompletedDecryptsLocalCiphertext() async throws {
        let noteID = UUID()
        let attachmentID = UUID()
        let plaintext = Data("preview-bytes".utf8)
        let udk = SymmetricKey(size: .bits256)
        let (warmNote, _) = try NoteViewModelTestSupport.makeSplitStoredNote(
            noteID: noteID,
            title: "Warm",
            body: "Body",
            udk: udk,
            attachmentPlaintexts: [
                (attachmentID, "doc.pdf", "application/pdf", plaintext),
            ],
            syncState: .synced
        )
        let coldNote = StoredNote(
            metadata: warmNote.metadata,
            wrappedFEK: warmNote.wrappedFEK,
            encryptedPayload: warmNote.encryptedPayload,
            syncState: .synced,
            attachmentCiphertexts: [:]
        )
        let noteRepository = StoredNoteMockRepository(notes: [noteID: coldNote])
        let noteSync = ControllableNoteSyncService()

        await noteSync.setHydrateAttachmentsHandler { id in
            await noteRepository.replaceNote(warmNote)
            await noteSync.emitHydration(
                AttachmentHydrationProgress(
                    noteID: id,
                    attachmentID: attachmentID,
                    bytesReceived: UInt64(plaintext.count),
                    totalBytes: UInt64(plaintext.count),
                    state: .completed
                )
            )
        }

        let viewModel = DefaultNoteDetailViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            vaultSession: StoredNoteMockVaultSession(udk: udk),
            navigator: MockNavigating(),
            noteSync: noteSync
        )

        await viewModel.load()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.attachmentData(for: attachmentID.uuidString), plaintext)
        XCTAssertNil(viewModel.attachmentProgressByID[attachmentID.uuidString])
    }

    func testRetryFailedAttachmentCallsSyncRetry() async throws {
        let noteID = UUID()
        let attachmentID = UUID()
        let udk = SymmetricKey(size: .bits256)
        let (noteData, _) = try NoteViewModelTestSupport.makeSplitStoredNote(
            noteID: noteID,
            title: "Retry",
            body: "Body",
            udk: udk,
            attachmentPlaintexts: [
                (attachmentID, "fail.bin", "application/octet-stream", Data([0xAA])),
            ],
            syncState: .synced
        )
        let coldNote = StoredNote(
            metadata: noteData.metadata,
            wrappedFEK: noteData.wrappedFEK,
            encryptedPayload: noteData.encryptedPayload,
            syncState: .synced,
            attachmentCiphertexts: [:]
        )
        let noteSync = ControllableNoteSyncService()
        let viewModel = DefaultNoteDetailViewModel(
            noteID: noteID,
            noteRepository: StoredNoteMockRepository(notes: [noteID: coldNote]),
            vaultSession: StoredNoteMockVaultSession(udk: udk),
            navigator: MockNavigating(),
            noteSync: noteSync
        )
        await viewModel.load()

        await noteSync.emitHydration(
            AttachmentHydrationProgress(
                noteID: noteID,
                attachmentID: attachmentID,
                bytesReceived: 0,
                totalBytes: 1,
                state: .failed
            )
        )
        try? await Task.sleep(nanoseconds: 50_000_000)

        await viewModel.retryAttachment(id: attachmentID.uuidString)

        let retries = await noteSync.retryAttachmentCalls
        XCTAssertEqual(retries.count, 1)
        XCTAssertEqual(retries.first?.noteID, noteID)
        XCTAssertEqual(retries.first?.attachmentID, attachmentID)
    }

    func testSaveWritesV2IndexAndAttachmentCiphertexts() async throws {
        let noteID = UUID()
        let udk = SymmetricKey(size: .bits256)
        let noteData = try NoteViewModelTestSupport.makeStoredNote(
            noteID: noteID,
            title: "Title",
            body: "Body",
            udk: udk,
            syncState: .synced
        )
        let noteRepository = StoredNoteMockRepository(notes: [noteID: noteData])
        let viewModel = DefaultNoteDetailViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            vaultSession: StoredNoteMockVaultSession(udk: udk),
            navigator: MockNavigating()
        )
        await viewModel.load()
        viewModel.addAttachment(
            NotePayload.Attachment(
                id: UUID().uuidString,
                filename: "new.txt",
                mime: "text/plain",
                data: Data("hello".utf8)
            )
        )

        await viewModel.save()

        let saved = try await noteRepository.storedNote(noteID: noteID)
        let fek = try unwrapFEK(saved.wrappedFEK, with: udk)
        let payload = try decryptPayload(saved.encryptedPayload, with: fek)
        XCTAssertEqual(payload.schemaVersion, 2)
        XCTAssertEqual(payload.attachments.count, 1)
        XCTAssertNil(payload.attachments[0].data)
        XCTAssertEqual(payload.attachments[0].filename, "new.txt")
        XCTAssertEqual(saved.attachmentCiphertexts.count, 1)
        let ciphertext = try XCTUnwrap(saved.attachmentCiphertexts.values.first)
        XCTAssertEqual(try decryptAttachmentFile(ciphertext, with: fek), Data("hello".utf8))
    }

    func testLoadMigratesInlineAttachmentsWhenRepositorySupportsIt() async throws {
        let noteID = UUID()
        let udk = SymmetricKey(size: .bits256)
        let noteData = try NoteViewModelTestSupport.makeStoredNote(
            noteID: noteID,
            title: "Legacy",
            body: "Body",
            udk: udk,
            attachments: [
                NotePayload.Attachment(
                    id: "legacy-1",
                    filename: "old.png",
                    mime: "image/png",
                    data: Data([0x01])
                ),
            ],
            syncState: .synced
        )
        let noteRepository = StoredNoteMockRepository(notes: [noteID: noteData])
        let viewModel = DefaultNoteDetailViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            vaultSession: StoredNoteMockVaultSession(udk: udk),
            navigator: MockNavigating()
        )

        await viewModel.load()

        let migrateCount = await noteRepository.migrateInlineCallCount
        XCTAssertEqual(migrateCount, 1)
        XCTAssertEqual(viewModel.attachmentData(for: "legacy-1"), Data([0x01]))
    }
}
