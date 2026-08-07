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
        syncState: NoteSyncState = .pendingSync,
        attachmentCiphertexts: [UUID: Data] = [:],
        schemaVersion: Int = 1
    ) throws -> StoredNote {
        let fek = generateSymmetricKey()
        let payload = NotePayload(
            body: Data(body.utf8),
            attachments: attachments,
            schemaVersion: schemaVersion
        )
        let encryptedPayload = try encryptPayload(payload, with: fek)
        let wrappedFEK = try wrapFEK(fek, with: udk)
        let metadata = NoteMetadata(
            noteID: noteID,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
            attachmentCount: UInt32(attachments.count),
            attachmentsTotalSize: attachments.reduce(0) { $0 + UInt64($1.size) }
        )
        return StoredNote(
            metadata: metadata,
            wrappedFEK: wrappedFEK,
            encryptedPayload: encryptedPayload,
            syncState: syncState,
            attachmentCiphertexts: attachmentCiphertexts
        )
    }

    static func makeSplitStoredNote(
        noteID: UUID,
        title: String,
        body: String,
        udk: SymmetricKey,
        attachmentPlaintexts: [(id: UUID, filename: String, mime: String, data: Data)],
        syncState: NoteSyncState = .synced
    ) throws -> (StoredNote, SymmetricKey) {
        let fek = generateSymmetricKey()
        var ciphertexts: [UUID: Data] = [:]
        var index: [NotePayload.Attachment] = []
        for item in attachmentPlaintexts {
            ciphertexts[item.id] = try encryptAttachmentFile(item.data, with: fek)
            index.append(
                NotePayload.Attachment(
                    id: item.id.uuidString,
                    filename: item.filename,
                    mime: item.mime,
                    size: item.data.count
                )
            )
        }
        let payload = NotePayload(body: Data(body.utf8), attachments: index, schemaVersion: 2)
        let encryptedPayload = try encryptPayload(payload, with: fek)
        let wrappedFEK = try wrapFEK(fek, with: udk)
        let metadata = NoteMetadata(
            noteID: noteID,
            title: title,
            createdAt: 1_700_000_000,
            updatedAt: 1_700_000_100,
            attachmentCount: UInt32(index.count),
            attachmentsTotalSize: index.reduce(0) { $0 + UInt64($1.size) }
        )
        let note = StoredNote(
            metadata: metadata,
            wrappedFEK: wrappedFEK,
            encryptedPayload: encryptedPayload,
            syncState: syncState,
            attachmentCiphertexts: ciphertexts
        )
        return (note, fek)
    }

    static func makeSharedNote(
        noteID: UUID,
        title: String,
        body: String,
        recipientPublicKey: Data,
        attachments: [NotePayload.Attachment] = [],
        createdAt: UInt64 = 1_700_000_000,
        updatedAt: UInt64 = 1_700_000_100,
        schemaVersion: Int = 1
    ) throws -> SharedNote {
        let fek = generateSymmetricKey()
        let payload = NotePayload(
            body: Data(body.utf8),
            attachments: attachments,
            schemaVersion: schemaVersion
        )
        let encryptedPayload = try encryptPayload(payload, with: fek)
        let recipientWrappedFEK = try wrapFEKForRecipient(fek, recipientPublicKey: recipientPublicKey)
        let metadata = NoteMetadata(
            noteID: noteID,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
            attachmentCount: UInt32(attachments.count),
            attachmentsTotalSize: attachments.reduce(0) { $0 + UInt64($1.size) }
        )
        return SharedNote(
            noteID: noteID,
            metadata: metadata,
            recipientWrappedFEK: recipientWrappedFEK,
            encryptedPayload: encryptedPayload
        )
    }
}

actor StoredNoteMockRepository: NoteRepository, InlineAttachmentMigrating {
    private var notes: [UUID: StoredNote]
    private(set) var writtenNotes: [StoredNote] = []
    private(set) var deletedNoteIDs: [UUID] = []
    private(set) var listNotesCallCount = 0
    private(set) var migrateInlineCallCount = 0
    private var migrateHandler: ((UUID, SymmetricKey) async throws -> Void)?

    init(notes: [UUID: StoredNote] = [:]) {
        self.notes = notes
    }

    func setMigrateHandler(_ handler: @escaping (UUID, SymmetricKey) async throws -> Void) {
        migrateHandler = handler
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

    func migrateInlineAttachmentsToSplit(noteID: UUID, fek: SymmetricKey) async throws {
        migrateInlineCallCount += 1
        if let migrateHandler {
            try await migrateHandler(noteID, fek)
        }
    }

    func storedNote(noteID: UUID) async throws -> StoredNote {
        try await readNote(noteID: noteID)
    }

    func replaceNote(_ note: StoredNote) {
        notes[note.metadata.noteID] = note
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
    private(set) var hydrateAttachmentsCallCount = 0
    private(set) var hydrateSharedAttachmentsCallCount = 0
    private(set) var retryAttachmentCalls: [(noteID: UUID, attachmentID: UUID)] = []
    private(set) var retrySharedAttachmentCalls: [(noteID: UUID, attachmentID: UUID)] = []

    nonisolated let syncOutcomes: AsyncStream<NoteSyncOutcome> = AsyncStream { $0.finish() }
    nonisolated let attachmentHydrationProgress: AsyncStream<AttachmentHydrationProgress> = AsyncStream { $0.finish() }

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

    func hydrateAttachments(noteID: UUID) async {
        _ = noteID
        hydrateAttachmentsCallCount += 1
    }

    func hydrateSharedAttachments(noteID: UUID) async {
        _ = noteID
        hydrateSharedAttachmentsCallCount += 1
    }

    func retryAttachment(noteID: UUID, attachmentID: UUID) async {
        retryAttachmentCalls.append((noteID, attachmentID))
    }

    func retrySharedAttachment(noteID: UUID, attachmentID: UUID) async {
        retrySharedAttachmentCalls.append((noteID, attachmentID))
    }
}

actor ControllableNoteSyncService: NoteSyncing {
    private var outcomeSubscribers: [UUID: AsyncStream<NoteSyncOutcome>.Continuation] = [:]
    private var hydrationSubscribers: [UUID: AsyncStream<AttachmentHydrationProgress>.Continuation] = [:]
    private(set) var hydrateAttachmentsCallCount = 0
    private(set) var hydrateSharedAttachmentsCallCount = 0
    private(set) var retryAttachmentCalls: [(noteID: UUID, attachmentID: UUID)] = []
    private(set) var retrySharedAttachmentCalls: [(noteID: UUID, attachmentID: UUID)] = []
    private var hydrateAttachmentsHandler: ((UUID) async -> Void)?
    private var hydrateSharedAttachmentsHandler: ((UUID) async -> Void)?

    nonisolated var syncOutcomes: AsyncStream<NoteSyncOutcome> {
        AsyncStream { continuation in
            Task { await self.addOutcomeSubscriber(continuation) }
        }
    }

    nonisolated var attachmentHydrationProgress: AsyncStream<AttachmentHydrationProgress> {
        AsyncStream { continuation in
            Task { await self.addHydrationSubscriber(continuation) }
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

    private func addHydrationSubscriber(
        _ continuation: AsyncStream<AttachmentHydrationProgress>.Continuation
    ) {
        let id = UUID()
        hydrationSubscribers[id] = continuation
        continuation.onTermination = { @Sendable [weak self] _ in
            Task { await self?.removeHydrationSubscriber(id) }
        }
    }

    private func removeHydrationSubscriber(_ id: UUID) {
        hydrationSubscribers.removeValue(forKey: id)
    }

    func emit(_ outcome: NoteSyncOutcome) {
        for continuation in outcomeSubscribers.values {
            continuation.yield(outcome)
        }
    }

    func emitHydration(_ progress: AttachmentHydrationProgress) {
        for continuation in hydrationSubscribers.values {
            continuation.yield(progress)
        }
    }

    func setHydrateAttachmentsHandler(_ handler: @escaping (UUID) async -> Void) {
        hydrateAttachmentsHandler = handler
    }

    func setHydrateSharedAttachmentsHandler(_ handler: @escaping (UUID) async -> Void) {
        hydrateSharedAttachmentsHandler = handler
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

    func hydrateAttachments(noteID: UUID) async {
        hydrateAttachmentsCallCount += 1
        if let hydrateAttachmentsHandler {
            await hydrateAttachmentsHandler(noteID)
        }
    }

    func hydrateSharedAttachments(noteID: UUID) async {
        hydrateSharedAttachmentsCallCount += 1
        if let hydrateSharedAttachmentsHandler {
            await hydrateSharedAttachmentsHandler(noteID)
        }
    }

    func retryAttachment(noteID: UUID, attachmentID: UUID) async {
        retryAttachmentCalls.append((noteID, attachmentID))
    }

    func retrySharedAttachment(noteID: UUID, attachmentID: UUID) async {
        retrySharedAttachmentCalls.append((noteID, attachmentID))
    }
}
