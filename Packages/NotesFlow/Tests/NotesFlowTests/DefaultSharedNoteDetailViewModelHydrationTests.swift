import CryptoKit
import Foundation
import NoteRepositoryProtocol
import SecureCrypto
import VaultSessionProtocol
import XCTest

@testable import NotesFlow

@MainActor
final class DefaultSharedNoteDetailViewModelHydrationTests: XCTestCase {
    func testLoadShowsBodyAndFilenamesBeforeSharedHydrationCompletes() async throws {
        let noteID = UUID()
        let attachmentID = UUID()
        let identity = generateIdentityKeyPair()
        let shared = try NoteViewModelTestSupport.makeSharedNote(
            noteID: noteID,
            title: "Shared cold",
            body: "Shared body now",
            recipientPublicKey: identity.publicKey,
            attachments: [
                NotePayload.Attachment(
                    id: attachmentID.uuidString,
                    filename: "shared.pdf",
                    mime: "application/pdf",
                    size: 4
                ),
            ],
            schemaVersion: 2
        )
        let summary = SharedNoteSummary(
            noteID: noteID,
            title: "Shared cold",
            updatedAt: shared.metadata.updatedAt,
            etag: "etag",
            ownerEmail: "owner@example.com",
            ownerID: UUID(),
            sharedAt: Date()
        )
        let noteRepository = SharedDetailMockNoteRepository(
            sharedNote: shared,
            sharedSummaries: [summary]
        )
        let noteSync = ControllableNoteSyncService()
        let hydrationStarted = expectation(description: "hydrateSharedAttachments started")

        await noteSync.setHydrateSharedAttachmentsHandler { id in
            XCTAssertEqual(id, noteID)
            hydrationStarted.fulfill()
            await noteSync.emitHydration(
                AttachmentHydrationProgress(
                    noteID: noteID,
                    attachmentID: attachmentID,
                    bytesReceived: 2,
                    totalBytes: 4,
                    state: .downloading
                )
            )
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        let viewModel = DefaultSharedNoteDetailViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            vaultSession: SharedDetailMockVaultSession(identityPrivateKey: identity.privateKey),
            noteSync: noteSync
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.title, "Shared cold")
        XCTAssertEqual(viewModel.body, "Shared body now")
        XCTAssertEqual(viewModel.attachmentItems.map(\.filename), ["shared.pdf"])
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.attachmentData(for: attachmentID.uuidString))

        await fulfillment(of: [hydrationStarted], timeout: 1.0)
        try? await Task.sleep(nanoseconds: 80_000_000)

        let progress = try XCTUnwrap(viewModel.attachmentProgressByID[attachmentID.uuidString])
        XCTAssertEqual(progress.state, .downloading)
        XCTAssertEqual(progress.bytesReceived, 2)

        let hydrateCount = await noteSync.hydrateSharedAttachmentsCallCount
        XCTAssertEqual(hydrateCount, 1)
    }

    func testRetryFailedSharedAttachmentCallsSyncRetry() async throws {
        let noteID = UUID()
        let attachmentID = UUID()
        let identity = generateIdentityKeyPair()
        let shared = try NoteViewModelTestSupport.makeSharedNote(
            noteID: noteID,
            title: "Shared",
            body: "Body",
            recipientPublicKey: identity.publicKey,
            attachments: [
                NotePayload.Attachment(
                    id: attachmentID.uuidString,
                    filename: "a.bin",
                    mime: "application/octet-stream",
                    size: 1
                ),
            ],
            schemaVersion: 2
        )
        let noteSync = ControllableNoteSyncService()
        let viewModel = DefaultSharedNoteDetailViewModel(
            noteID: noteID,
            noteRepository: SharedDetailMockNoteRepository(
                sharedNote: shared,
                sharedSummaries: []
            ),
            vaultSession: SharedDetailMockVaultSession(identityPrivateKey: identity.privateKey),
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

        let retries = await noteSync.retrySharedAttachmentCalls
        XCTAssertEqual(retries.count, 1)
        XCTAssertEqual(retries.first?.attachmentID, attachmentID)
    }
}

private actor SharedDetailMockNoteRepository: NoteRepository {
    private let sharedNote: SharedNote
    private let sharedSummaries: [SharedNoteSummary]
    private var ownedNotes: [UUID: StoredNote]

    init(
        sharedNote: SharedNote,
        sharedSummaries: [SharedNoteSummary],
        ownedNotes: [UUID: StoredNote] = [:]
    ) {
        self.sharedNote = sharedNote
        self.sharedSummaries = sharedSummaries
        self.ownedNotes = ownedNotes
    }

    func listNotes() async throws -> [NoteSummary] { [] }
    func readNote(noteID: UUID) async throws -> StoredNote {
        guard let note = ownedNotes[noteID] else {
            throw NoteRepositoryError.noteNotFound
        }
        return note
    }
    func writeNote(_ note: StoredNote) async throws {
        ownedNotes[note.metadata.noteID] = note
    }
    func deleteNote(noteID: UUID) async throws {}
    func shareNote(noteID: UUID, recipientEmail: String, wrappedFEK: Data) async throws {
        throw NoteRepositoryError.notSupported
    }
    func listSharedNotes() async throws -> [SharedNoteSummary] { sharedSummaries }
    func readSharedNote(noteID: UUID) async throws -> SharedNote {
        guard sharedNote.noteID == noteID else {
            throw NoteRepositoryError.noteNotFound
        }
        return sharedNote
    }

    func deleteSharedNote(noteID: UUID) async throws {
        _ = noteID
        throw NoteRepositoryError.notSupported
    }

    func replaceOwnedNote(_ note: StoredNote) {
        ownedNotes[note.metadata.noteID] = note
    }
}

private actor SharedDetailMockVaultSession: VaultSessionProtocol {
    private let identityPrivate: Data

    init(identityPrivateKey: Data) {
        identityPrivate = identityPrivateKey
    }

    var isActive: Bool { true }
    nonisolated var changes: AsyncStream<Bool> { AsyncStream { $0.finish() } }
    func establish(_ keys: VaultSessionKeys) {}
    func clear() {}
    func udk() throws -> SymmetricKey { .init(size: .bits256) }
    func identityPrivateKey() throws -> Data { identityPrivate }
}
