import Foundation
import NoteRepositoryProtocol

struct NoteSyncUploadCandidate: Sendable {
    let note: StoredNote
    let etag: String?
}

struct NoteDeleteSyncEntry: Sendable {
    let noteID: UUID
    let etag: String?
}

protocol NoteSyncLocalStoring: Actor {
    func uploadCandidates() async throws -> [NoteSyncUploadCandidate]
    func pendingDeleteEntries() async throws -> [NoteDeleteSyncEntry]
    func markNoteSynced(noteID: UUID, updatedAt: UInt64, etag: String?) async throws
    func finalizeDeletedNote(noteID: UUID) async throws
    func replaceNoteWithRemote(_ note: StoredNote, etag: String?) async throws
}

protocol NoteSyncRemoteStoring: Actor {
    func uploadNote(_ note: StoredNote, ifMatch etag: String?) async throws -> NoteUploadResult
    func readNote(noteID: UUID) async throws -> StoredNote
    func deleteNote(noteID: UUID) async throws
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
                etag: etag
            )
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
            syncState: .synced
        )
        try await writeNote(syncedNote)
        try await markNoteSynced(
            noteID: remote.metadata.noteID,
            updatedAt: remote.metadata.updatedAt,
            etag: etag
        )
    }
}

extension NetworkNoteRepository: NoteSyncRemoteStoring {}
