import Foundation
import NoteRepositoryProtocol
import VaultRepository

public actor LocalFirstNoteSyncService: NoteSyncing {
    public nonisolated let syncOutcomes: AsyncStream<NoteSyncOutcome>
    private let outcomeContinuation: AsyncStream<NoteSyncOutcome>.Continuation

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
        var continuation: AsyncStream<NoteSyncOutcome>.Continuation!
        syncOutcomes = AsyncStream { continuation = $0 }
        outcomeContinuation = continuation
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
        var continuation: AsyncStream<NoteSyncOutcome>.Continuation!
        syncOutcomes = AsyncStream { continuation = $0 }
        outcomeContinuation = continuation
        self.localNotes = localNotes
        self.remoteNotes = remoteNotes
        self.localVault = localVault
        self.remoteVault = remoteVault
    }

    public nonisolated func scheduleFlush() {
        Task {
            await flushPending()
        }
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
        let noteID = candidate.note.metadata.noteID
        do {
            let result = try await remoteNotes.uploadNote(
                candidate.note,
                ifMatch: candidate.etag,
                uploadSessionStore: localNotes
            )
            let updatedAt = resolvedUpdatedAt(
                server: result.updatedAt,
                local: candidate.note.metadata.updatedAt
            )
            try await localNotes.markNoteSynced(
                noteID: noteID,
                updatedAt: updatedAt,
                etag: result.etag
            )
            emitOutcome(
                .uploaded(
                    noteID: noteID,
                    syncState: result.syncState,
                    updatedAt: updatedAt,
                    etag: result.etag
                )
            )
        } catch NoteRepositoryError.serverError(statusCode: 409) {
            await resolveConflict(candidate)
        } catch {
            emitOutcome(.uploadFailed(noteID: noteID))
        }
    }

    private func resolveConflict(_ candidate: NoteSyncUploadCandidate) async {
        let noteID = candidate.note.metadata.noteID
        guard let remote = try? await remoteNotes.readNote(noteID: noteID) else {
            emitOutcome(.uploadFailed(noteID: noteID))
            return
        }

        let localUpdatedAt = candidate.note.metadata.updatedAt
        let remoteUpdatedAt = remote.metadata.updatedAt

        if localUpdatedAt > remoteUpdatedAt {
            await retryUploadWithoutConditionalMatch(candidate)
        } else if remoteUpdatedAt > localUpdatedAt {
            try? await localNotes.replaceNoteWithRemote(remote, etag: candidate.etag)
            emitOutcome(
                .uploaded(
                    noteID: noteID,
                    syncState: .synced,
                    updatedAt: remote.metadata.updatedAt,
                    etag: candidate.etag
                )
            )
        }
    }

    private func retryUploadWithoutConditionalMatch(_ candidate: NoteSyncUploadCandidate) async {
        let noteID = candidate.note.metadata.noteID
        guard let result = try? await remoteNotes.uploadNote(
            candidate.note,
            ifMatch: nil,
            uploadSessionStore: localNotes
        ) else {
            emitOutcome(.uploadFailed(noteID: noteID))
            return
        }
        let updatedAt = resolvedUpdatedAt(
            server: result.updatedAt,
            local: candidate.note.metadata.updatedAt
        )
        try? await localNotes.markNoteSynced(
            noteID: noteID,
            updatedAt: updatedAt,
            etag: result.etag
        )
        emitOutcome(
            .uploaded(
                noteID: noteID,
                syncState: result.syncState,
                updatedAt: updatedAt,
                etag: result.etag
            )
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

    private func emitOutcome(_ outcome: NoteSyncOutcome) {
        outcomeContinuation.yield(outcome)
    }

    private func resolvedUpdatedAt(server: UInt64, local: UInt64) -> UInt64 {
        server == 0 ? local : server
    }
}
