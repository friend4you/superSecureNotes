import Foundation
import NoteRepositoryProtocol

public actor LocalFirstNoteSyncService: NoteSyncing {
    private let localNotes: any NoteSyncLocalStoring
    private let remoteNotes: any NoteSyncRemoteStoring

    public init(
        localNotes: LocalNoteRepository,
        remoteNotes: NetworkNoteRepository
    ) {
        self.localNotes = localNotes
        self.remoteNotes = remoteNotes
    }

    init(
        localNotes: any NoteSyncLocalStoring,
        remoteNotes: any NoteSyncRemoteStoring
    ) {
        self.localNotes = localNotes
        self.remoteNotes = remoteNotes
    }

    public func flushPending() async {
        await flushUploads()
        await flushDeletes()
    }

    private func flushUploads() async {
        guard let candidates = try? await localNotes.uploadCandidates() else {
            return
        }
        for candidate in candidates {
            await pushNote(candidate)
        }
    }

    private func pushNote(_ candidate: NoteSyncUploadCandidate) async {
        do {
            let result = try await remoteNotes.uploadNote(
                candidate.note,
                ifMatch: candidate.etag
            )
            try await localNotes.markNoteSynced(
                noteID: candidate.note.metadata.noteID,
                updatedAt: resolvedUpdatedAt(
                    server: result.updatedAt,
                    local: candidate.note.metadata.updatedAt
                ),
                etag: result.etag
            )
        } catch NoteRepositoryError.serverError(statusCode: 409) {
            await resolveConflict(candidate)
        } catch {
            return
        }
    }

    private func resolveConflict(_ candidate: NoteSyncUploadCandidate) async {
        guard let remote = try? await remoteNotes.readNote(noteID: candidate.note.metadata.noteID) else {
            return
        }

        let localUpdatedAt = candidate.note.metadata.updatedAt
        let remoteUpdatedAt = remote.metadata.updatedAt

        if localUpdatedAt > remoteUpdatedAt {
            await retryUploadWithoutConditionalMatch(candidate)
        } else if remoteUpdatedAt > localUpdatedAt {
            try? await localNotes.replaceNoteWithRemote(remote, etag: candidate.etag)
        }
    }

    private func retryUploadWithoutConditionalMatch(_ candidate: NoteSyncUploadCandidate) async {
        guard let result = try? await remoteNotes.uploadNote(candidate.note, ifMatch: nil) else {
            return
        }
        try? await localNotes.markNoteSynced(
            noteID: candidate.note.metadata.noteID,
            updatedAt: resolvedUpdatedAt(
                server: result.updatedAt,
                local: candidate.note.metadata.updatedAt
            ),
            etag: result.etag
        )
    }

    private func flushDeletes() async {
        guard let entries = try? await localNotes.pendingDeleteEntries() else {
            return
        }
        for entry in entries {
            do {
                try await remoteNotes.deleteNote(noteID: entry.noteID)
                try await localNotes.finalizeDeletedNote(noteID: entry.noteID)
            } catch {
                continue
            }
        }
    }

    private func resolvedUpdatedAt(server: UInt64, local: UInt64) -> UInt64 {
        server == 0 ? local : server
    }
}
