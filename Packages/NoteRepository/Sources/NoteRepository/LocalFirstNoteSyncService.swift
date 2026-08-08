import CryptoKit
import Foundation
import NoteRepositoryProtocol
import VaultRepository

public actor LocalFirstNoteSyncService: NoteSyncing {
    public typealias NoteFEKProvider = @Sendable (UUID) async throws -> SymmetricKey?

    private let outcomeMulticaster = NoteSyncOutcomeMulticaster()
    let hydrationProgressMulticaster = AttachmentHydrationProgressMulticaster()
    var inFlightHydrations: [HydrationKey: Task<Void, Never>] = [:]

    public nonisolated var syncOutcomes: AsyncStream<NoteSyncOutcome> {
        outcomeMulticaster.stream()
    }

    let localNotes: any NoteSyncLocalStoring
    let remoteNotes: any NoteSyncRemoteStoring
    private let localVault: any NoteSyncLocalVaultStoring
    private let remoteVault: any NoteSyncRemoteVaultStoring
    private let noteFEKProvider: NoteFEKProvider?

    public init(
        localNotes: LocalNoteRepository,
        remoteNotes: NetworkNoteRepository,
        localVault: LocalVaultRepository,
        remoteVault: NetworkVaultRepository,
        noteFEKProvider: NoteFEKProvider? = nil
    ) {
        self.localNotes = localNotes
        self.remoteNotes = remoteNotes
        self.localVault = localVault
        self.remoteVault = remoteVault
        self.noteFEKProvider = noteFEKProvider
    }

    init(
        localNotes: any NoteSyncLocalStoring,
        remoteNotes: any NoteSyncRemoteStoring,
        localVault: any NoteSyncLocalVaultStoring,
        remoteVault: any NoteSyncRemoteVaultStoring,
        noteFEKProvider: NoteFEKProvider? = nil
    ) {
        self.localNotes = localNotes
        self.remoteNotes = remoteNotes
        self.localVault = localVault
        self.remoteVault = remoteVault
        self.noteFEKProvider = noteFEKProvider
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

    public func pullVaultHeaderIfLocalMissing() async throws -> Data? {
        if (try? await localVault.readHeader()) != nil {
            return nil
        }

        let header = try await remoteVault.readHeader()
        try await localVault.writeHeader(header)
        return header
    }

    public func pullRemoteNotesCatalog() async throws {
        try await importRemoteNotes()
    }

    public func pullCatalogIfLocalVaultMissing() async throws -> Data? {
        guard let header = try await pullVaultHeaderIfLocalMissing() else {
            return nil
        }
        try await pullRemoteNotesCatalog()
        return header
    }

    public func uploadVaultHeaderOrThrow(_ header: Data) async throws {
        try await remoteVault.writeHeader(header)
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
        let prepared = await prepareCandidateForUpload(candidate)
        do {
            let result = try await remoteNotes.uploadNote(
                prepared.note,
                ifMatch: prepared.etag,
                uploadSessionStore: localNotes
            )
            let updatedAt = resolvedUpdatedAt(
                server: result.updatedAt,
                local: prepared.note.metadata.updatedAt
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
            await retryUploadWithoutConditionalMatch(prepared)
        } catch {
            emitOutcome(.uploadFailed(noteID: noteID))
        }
    }

    private func prepareCandidateForUpload(
        _ candidate: NoteSyncUploadCandidate
    ) async -> NoteSyncUploadCandidate {
        let noteID = candidate.note.metadata.noteID
        guard let noteFEKProvider,
              let fek = try? await noteFEKProvider(noteID)
        else {
            return candidate
        }

        do {
            try await localNotes.migrateInlineAttachmentsToSplit(noteID: noteID, fek: fek)
            let candidates = try await localNotes.uploadCandidates()
            if let refreshed = candidates.first(where: { $0.note.metadata.noteID == noteID }) {
                return refreshed
            }
        } catch {
            return candidate
        }
        return candidate
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
        outcomeMulticaster.yield(outcome)
    }

    private func resolvedUpdatedAt(server: UInt64, local: UInt64) -> UInt64 {
        server == 0 ? local : server
    }
}
