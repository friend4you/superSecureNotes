import CryptoKit
import Foundation
import NoteRepositoryProtocol
import SecureCrypto
import VaultSessionProtocol

enum NoteViewModelTestSupport {
    static func makeStoredNote(
        noteID: UUID,
        title: String,
        body: String,
        udk: SymmetricKey,
        attachments: [NotePayload.Attachment] = [],
        createdAt: UInt64 = 1_700_000_000,
        updatedAt: UInt64 = 1_700_000_100,
        syncState: NoteSyncState = .pendingSync
    ) throws -> StoredNote {
        let fek = generateSymmetricKey()
        let payload = NotePayload(body: Data(body.utf8), attachments: attachments)
        let encryptedPayload = try encryptPayload(payload, with: fek)
        let wrappedFEK = try wrapFEK(fek, with: udk)
        let metadata = NoteMetadata(
            noteID: noteID,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
            attachmentCount: UInt32(attachments.count),
            attachmentsTotalSize: attachments.reduce(0) { $0 + UInt64($1.data.count) }
        )
        return StoredNote(
            metadata: metadata,
            wrappedFEK: wrappedFEK,
            encryptedPayload: encryptedPayload,
            syncState: syncState
        )
    }

    static func makeSharedNote(
        noteID: UUID,
        title: String,
        body: String,
        recipientPublicKey: Data,
        attachments: [NotePayload.Attachment] = [],
        createdAt: UInt64 = 1_700_000_000,
        updatedAt: UInt64 = 1_700_000_100
    ) throws -> SharedNote {
        let fek = generateSymmetricKey()
        let payload = NotePayload(body: Data(body.utf8), attachments: attachments)
        let encryptedPayload = try encryptPayload(payload, with: fek)
        let recipientWrappedFEK = try wrapFEKForRecipient(fek, recipientPublicKey: recipientPublicKey)
        let metadata = NoteMetadata(
            noteID: noteID,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
            attachmentCount: UInt32(attachments.count),
            attachmentsTotalSize: attachments.reduce(0) { $0 + UInt64($1.data.count) }
        )
        return SharedNote(
            noteID: noteID,
            metadata: metadata,
            recipientWrappedFEK: recipientWrappedFEK,
            encryptedPayload: encryptedPayload
        )
    }
}

actor StoredNoteMockRepository: NoteRepository {
    private var notes: [UUID: StoredNote]
    private(set) var writtenNotes: [StoredNote] = []
    private(set) var deletedNoteIDs: [UUID] = []
    private(set) var listNotesCallCount = 0

    init(notes: [UUID: StoredNote] = [:]) {
        self.notes = notes
    }

    func listNotes() async throws -> [NoteSummary] {
        listNotesCallCount += 1
        return notes.values.map {
            NoteSummary(
                noteID: $0.metadata.noteID,
                title: $0.metadata.title,
                updatedAt: $0.metadata.updatedAt,
                syncState: $0.syncState
            )
        }
    }

    func readNote(noteID: UUID) async throws -> StoredNote {
        guard let note = notes[noteID] else {
            throw NoteRepositoryError.noteNotFound
        }
        return note
    }

    func writeNote(_ note: StoredNote) async throws {
        writtenNotes.append(note)
        notes[note.metadata.noteID] = note
    }

    func deleteNote(noteID: UUID) async throws {
        deletedNoteIDs.append(noteID)
        notes.removeValue(forKey: noteID)
    }

    func shareNote(noteID: UUID, recipientEmail: String, wrappedFEK: Data) async throws {
        _ = noteID
        _ = recipientEmail
        _ = wrappedFEK
        throw NoteRepositoryError.notSupported
    }

    func listSharedNotes() async throws -> [SharedNoteSummary] {
        []
    }

    func readSharedNote(noteID: UUID) async throws -> SharedNote {
        _ = noteID
        throw NoteRepositoryError.notSupported
    }

    func deleteSharedNote(noteID: UUID) async throws {
        _ = noteID
        throw NoteRepositoryError.notSupported
    }


    func storedNote(noteID: UUID) async throws -> StoredNote {
        try await readNote(noteID: noteID)
    }
}

actor StoredNoteMockVaultSession: VaultSessionProtocol {
    private let key: SymmetricKey

    init(udk: SymmetricKey = SymmetricKey(size: .bits256)) {
        key = udk
    }

    var isActive: Bool { true }

    nonisolated var changes: AsyncStream<Bool> {
        AsyncStream { $0.finish() }
    }

    func establish(_ keys: VaultSessionKeys) {}
    func clear() {}
    func udk() throws -> SymmetricKey { key }
    func identityPrivateKey() throws -> Data { Data(repeating: 0x01, count: 32) }
}

actor RecordingNoteSyncService: NoteSyncing {
    private(set) var scheduleFlushCallCount = 0

    nonisolated let syncOutcomes: AsyncStream<NoteSyncOutcome> = AsyncStream { $0.finish() }

    func flushPending() async {}

    func pullVaultHeaderIfLocalMissing() async throws -> Data? {
        nil
    }

    func pullRemoteNotesCatalog() async throws {}

    func pullCatalogIfLocalVaultMissing() async throws -> Data? {
        nil
    }

    func uploadVaultHeaderOrThrow(_ header: Data) async throws {}

    nonisolated func scheduleFlush() {
        Task { await recordScheduleFlush() }
    }

    private func recordScheduleFlush() {
        scheduleFlushCallCount += 1
    }

    nonisolated func scheduleVaultHeaderUpload(_ header: Data) {}
}

actor ControllableNoteSyncService: NoteSyncing {
    private var outcomeSubscribers: [UUID: AsyncStream<NoteSyncOutcome>.Continuation] = [:]

    nonisolated var syncOutcomes: AsyncStream<NoteSyncOutcome> {
        AsyncStream { continuation in
            Task { await self.addOutcomeSubscriber(continuation) }
        }
    }

    private func addOutcomeSubscriber(_ continuation: AsyncStream<NoteSyncOutcome>.Continuation) {
        let id = UUID()
        outcomeSubscribers[id] = continuation
        continuation.onTermination = { @Sendable [weak self] _ in
            Task { await self?.removeOutcomeSubscriber(id) }
        }
    }

    private func removeOutcomeSubscriber(_ id: UUID) {
        outcomeSubscribers.removeValue(forKey: id)
    }

    func emit(_ outcome: NoteSyncOutcome) {
        for continuation in outcomeSubscribers.values {
            continuation.yield(outcome)
        }
    }

    func flushPending() async {}

    func pullVaultHeaderIfLocalMissing() async throws -> Data? {
        nil
    }

    func pullRemoteNotesCatalog() async throws {}

    func pullCatalogIfLocalVaultMissing() async throws -> Data? {
        nil
    }

    func uploadVaultHeaderOrThrow(_ header: Data) async throws {}

    nonisolated func scheduleFlush() {}

    nonisolated func scheduleVaultHeaderUpload(_ header: Data) {}
}
