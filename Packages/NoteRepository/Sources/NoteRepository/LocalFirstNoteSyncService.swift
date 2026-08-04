import Foundation
import NoteRepositoryProtocol
import VaultRepository

public actor LocalFirstNoteSyncService: NoteSyncing {
    private let localNotes: any NoteSyncLocalStoring
    private let remoteNotes: any NoteSyncRemoteStoring
    private let localVault: any NoteSyncLocalVaultStoring
    private let remoteVault: any NoteSyncRemoteVaultStoring

    public init(
        localNotes: LocalNoteRepository,
        remoteNotes: NetworkNoteRepository,
        localVault: LocalVaultRepository,
        remoteVault: NetworkVaultRepository
    ) {
        self.localNotes = localNotes
        self.remoteNotes = remoteNotes
        self.localVault = localVault
        self.remoteVault = remoteVault
    }

    init(
        localNotes: any NoteSyncLocalStoring,
        remoteNotes: any NoteSyncRemoteStoring,
        localVault: any NoteSyncLocalVaultStoring,
        remoteVault: any NoteSyncRemoteVaultStoring
    ) {
        self.localNotes = localNotes
        self.remoteNotes = remoteNotes
        self.localVault = localVault
        self.remoteVault = remoteVault
    }

    public func flushPending() async {
        await flushUploads()
        await flushDeletes()
    }

    public func pullCatalogIfLocalVaultMissing() async throws -> Data? {
        if (try? await localVault.readHeader()) != nil {
            return nil
        }

        let header = try await remoteVault.readHeader()
        try await localVault.writeHeader(header)
        try await importRemoteNotes()
        return header
    }

    public nonisolated func scheduleVaultHeaderUpload(_ header: Data) {
        Task {
            await uploadVaultHeader(header)
        }
    }

    private func uploadVaultHeader(_ header: Data) async {
        try? await remoteVault.writeHeader(header)
    }

    private func importRemoteNotes() async throws {
        let summaries = try await remoteNotes.listNotes()
        for summary in summaries {
            let note = try await remoteNotes.readNote(noteID: summary.noteID)
            try await localNotes.importSyncedNote(note, etag: summary.etag)
        }
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
