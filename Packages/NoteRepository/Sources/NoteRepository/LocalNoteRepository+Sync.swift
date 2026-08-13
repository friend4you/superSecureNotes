import CryptoKit
import Foundation
import NoteRepositoryProtocol
import VaultRepository
import VaultRepositoryProtocol

struct NoteSyncUploadCandidate: Sendable {
    let note: StoredNote
    let etag: String?
}

struct NoteDeleteSyncEntry: Sendable {
    let noteID: UUID
    let etag: String?
}

protocol NoteSyncLocalStoring: Actor, NoteUploadSessionStoring, AttachmentUploadSessionStoring {
    func uploadCandidates() async throws -> [NoteSyncUploadCandidate]
    func pendingDeleteEntries() async throws -> [NoteDeleteSyncEntry]
    func listNoteSummaries() async throws -> [NoteSummary]
    func markNoteSynced(noteID: UUID, updatedAt: UInt64, etag: String?) async throws
    func finalizeDeletedNote(noteID: UUID) async throws
    func replaceNoteWithRemote(_ note: StoredNote, etag: String?) async throws
    func importSyncedNote(_ note: StoredNote, etag: String?) async throws
    func migrateInlineAttachmentsToSplit(noteID: UUID, fek: SymmetricKey) async throws
    func attachmentFileExists(noteID: UUID, attachmentID: UUID) -> Bool
    func listAttachmentIndexRows(noteID: UUID) async throws -> [AttachmentIndexRow]
    func writeAttachmentFile(
        noteID: UUID,
        attachmentID: UUID,
        ciphertext: Data,
        etag: String?
    ) async throws
}

protocol NoteUploadSessionStoring: Actor {
    func fetchUploadSession(noteID: UUID) async throws -> NoteUploadSessionRecord?
    func upsertUploadSession(_ record: NoteUploadSessionRecord) async throws
    func markUploadChunkCompleted(noteID: UUID, chunkIndex: Int) async throws
    func deleteUploadSession(noteID: UUID) async throws
}

protocol AttachmentUploadSessionStoring: Actor {
    func fetchAttachmentUploadSession(
        noteID: UUID,
        attachmentID: UUID
    ) async throws -> AttachmentUploadSessionRecord?
    func upsertAttachmentUploadSession(_ record: AttachmentUploadSessionRecord) async throws
    func markAttachmentUploadChunkCompleted(
        noteID: UUID,
        attachmentID: UUID,
        chunkIndex: Int
    ) async throws
    func deleteAttachmentUploadSession(noteID: UUID, attachmentID: UUID) async throws
}

protocol NoteSyncRemoteStoring: Actor {
    func listNotes(includeDeleted: Bool) async throws -> [NoteSummary]
    func uploadNote(
        _ note: StoredNote,
        ifMatch etag: String?,
        uploadSessionStore: (any AttachmentUploadSessionStoring)?
    ) async throws -> NoteUploadResult
    func readNote(noteID: UUID) async throws -> StoredNote
    func deleteNote(noteID: UUID) async throws
    func listAttachments(noteID: UUID) async throws -> [RemoteAttachmentSummary]
    func readAttachment(
        noteID: UUID,
        summary: RemoteAttachmentSummary,
        onBytesReceived: (@Sendable (UInt64) -> Void)?
    ) async throws -> Data
    func listSharedAttachments(noteID: UUID) async throws -> [RemoteAttachmentSummary]
    func readSharedAttachment(
        noteID: UUID,
        summary: RemoteAttachmentSummary,
        onBytesReceived: (@Sendable (UInt64) -> Void)?
    ) async throws -> Data
}

protocol NoteSyncLocalVaultStoring: Actor {
    func readHeader() async throws -> Data
    func writeHeader(_ header: Data) async throws
}

protocol NoteSyncRemoteVaultStoring: Actor {
    func readHeader() async throws -> Data
    func writeHeader(_ header: Data) async throws
}

extension LocalNoteRepository: NoteSyncLocalStoring {
    func uploadCandidates() async throws -> [NoteSyncUploadCandidate] {
        try await requireOpen()
        let rows = try await notesIndexStore.listRows(withSyncState: .pendingSync)
        var candidates: [NoteSyncUploadCandidate] = []
        for row in rows {
            let note = try await readNote(noteID: row.noteID)
            candidates.append(NoteSyncUploadCandidate(note: note, etag: row.etag))
        }
        return candidates
    }

    func pendingDeleteEntries() async throws -> [NoteDeleteSyncEntry] {
        try await requireOpen()
        let rows = try await notesIndexStore.listRows(withSyncState: .pendingDelete)
        return rows.map { NoteDeleteSyncEntry(noteID: $0.noteID, etag: $0.etag) }
    }

    func listNoteSummaries() async throws -> [NoteSummary] {
        try await listNotes()
    }

    func markNoteSynced(noteID: UUID, updatedAt: UInt64, etag: String?) async throws {
        try await requireOpen()
        guard let row = try await notesIndexStore.fetchNote(noteID: noteID) else {
            return
        }
        try await notesIndexStore.upsertNote(
            NoteIndexRow(
                noteID: row.noteID,
                title: row.title,
                createdAt: row.createdAt,
                updatedAt: updatedAt,
                attachmentCount: row.attachmentCount,
                attachmentsTotalSize: row.attachmentsTotalSize,
                wrappedFEK: row.wrappedFEK,
                syncState: .synced,
                bodyEtag: row.bodyEtag,
                etag: etag
            )
        )
        try await notesIndexStore.deleteUploadSession(noteID: noteID)
    }

    func fetchUploadSession(noteID: UUID) async throws -> NoteUploadSessionRecord? {
        try await requireOpen()
        return try await notesIndexStore.fetchUploadSession(noteID: noteID)
    }

    func upsertUploadSession(_ record: NoteUploadSessionRecord) async throws {
        try await requireOpen()
        try await notesIndexStore.upsertUploadSession(record)
    }

    func markUploadChunkCompleted(noteID: UUID, chunkIndex: Int) async throws {
        try await requireOpen()
        try await notesIndexStore.markUploadChunkCompleted(noteID: noteID, chunkIndex: chunkIndex)
    }

    func deleteUploadSession(noteID: UUID) async throws {
        try await requireOpen()
        try await notesIndexStore.deleteUploadSession(noteID: noteID)
    }

    func fetchAttachmentUploadSession(
        noteID: UUID,
        attachmentID: UUID
    ) async throws -> AttachmentUploadSessionRecord? {
        try await requireOpen()
        return try await notesIndexStore.fetchAttachmentUploadSession(
            noteID: noteID,
            attachmentID: attachmentID
        )
    }

    func upsertAttachmentUploadSession(_ record: AttachmentUploadSessionRecord) async throws {
        try await requireOpen()
        try await notesIndexStore.upsertAttachmentUploadSession(record)
    }

    func markAttachmentUploadChunkCompleted(
        noteID: UUID,
        attachmentID: UUID,
        chunkIndex: Int
    ) async throws {
        try await requireOpen()
        try await notesIndexStore.markAttachmentUploadChunkCompleted(
            noteID: noteID,
            attachmentID: attachmentID,
            chunkIndex: chunkIndex
        )
    }

    func deleteAttachmentUploadSession(noteID: UUID, attachmentID: UUID) async throws {
        try await requireOpen()
        try await notesIndexStore.deleteAttachmentUploadSession(
            noteID: noteID,
            attachmentID: attachmentID
        )
    }

    func finalizeDeletedNote(noteID: UUID) async throws {
        try await requireOpen()
        try await notesIndexStore.deleteNote(noteID: noteID)
    }

    func replaceNoteWithRemote(_ remote: StoredNote, etag: String?) async throws {
        let syncedNote = StoredNote(
            metadata: remote.metadata,
            wrappedFEK: remote.wrappedFEK,
            encryptedPayload: remote.encryptedPayload,
            syncState: .synced,
            attachmentCiphertexts: remote.attachmentCiphertexts
        )
        try await writeNote(syncedNote)
        try await markNoteSynced(
            noteID: remote.metadata.noteID,
            updatedAt: remote.metadata.updatedAt,
            etag: etag
        )
    }

    func importSyncedNote(_ note: StoredNote, etag: String?) async throws {
        try await replaceNoteWithRemote(note, etag: etag)
    }
}

extension NetworkNoteRepository: NoteSyncRemoteStoring {}

extension LocalVaultRepository: NoteSyncLocalVaultStoring {}

extension NetworkVaultRepository: NoteSyncRemoteVaultStoring {}
