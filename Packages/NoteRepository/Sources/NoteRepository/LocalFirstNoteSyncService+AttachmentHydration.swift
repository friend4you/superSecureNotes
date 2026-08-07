import Foundation
import NoteRepositoryProtocol

extension LocalFirstNoteSyncService {
    private static let maxConcurrentAttachmentDownloads = 3

    public nonisolated var attachmentHydrationProgress: AsyncStream<AttachmentHydrationProgress> {
        hydrationProgressMulticaster.stream()
    }

    public func hydrateAttachments(noteID: UUID) async {
        await startOrJoinHydration(noteID: noteID, shared: false)
    }

    public func hydrateSharedAttachments(noteID: UUID) async {
        await startOrJoinHydration(noteID: noteID, shared: true)
    }

    public func retryAttachment(noteID: UUID, attachmentID: UUID) async {
        await retrySingleAttachment(noteID: noteID, attachmentID: attachmentID, shared: false)
    }

    public func retrySharedAttachment(noteID: UUID, attachmentID: UUID) async {
        await retrySingleAttachment(noteID: noteID, attachmentID: attachmentID, shared: true)
    }

    private func startOrJoinHydration(noteID: UUID, shared: Bool) async {
        let key = HydrationKey(noteID: noteID, shared: shared)
        if let existing = inFlightHydrations[key] {
            await withTaskCancellationHandler {
                _ = await existing.value
            } onCancel: {}
            return
        }

        let task = Task {
            await self.runHydration(noteID: noteID, shared: shared)
        }
        inFlightHydrations[key] = task
        await withTaskCancellationHandler {
            _ = await task.value
            self.inFlightHydrations[key] = nil
        } onCancel: {}
    }

    private func runHydration(noteID: UUID, shared: Bool) async {
        do {
            if try await hasWarmLocalAttachments(noteID: noteID) {
                return
            }

            let remote = try await listRemoteAttachments(noteID: noteID, shared: shared)
            var missing: [RemoteAttachmentSummary] = []
            for summary in remote {
                let exists = await localNotes.attachmentFileExists(
                    noteID: noteID,
                    attachmentID: summary.attachmentID
                )
                if !exists {
                    missing.append(summary)
                }
            }
            guard !missing.isEmpty else {
                return
            }

            await downloadAttachments(noteID: noteID, attachments: missing, shared: shared)
        } catch {
            return
        }
    }

    private func retrySingleAttachment(noteID: UUID, attachmentID: UUID, shared: Bool) async {
        let key = HydrationKey(noteID: noteID, shared: shared)
        if let existing = inFlightHydrations[key] {
            _ = await existing.value
        }

        do {
            let remote = try await listRemoteAttachments(noteID: noteID, shared: shared)
            guard let summary = remote.first(where: { $0.attachmentID == attachmentID }) else {
                return
            }
            await downloadOneAttachment(noteID: noteID, summary: summary, shared: shared)
        } catch {
            return
        }
    }

    private func hasWarmLocalAttachments(noteID: UUID) async throws -> Bool {
        let rows = try await localNotes.listAttachmentIndexRows(noteID: noteID)
        guard !rows.isEmpty else {
            return false
        }
        for row in rows {
            let exists = await localNotes.attachmentFileExists(
                noteID: noteID,
                attachmentID: row.attachmentID
            )
            if !exists {
                return false
            }
        }
        return true
    }

    private func listRemoteAttachments(
        noteID: UUID,
        shared: Bool
    ) async throws -> [RemoteAttachmentSummary] {
        if shared {
            return try await remoteNotes.listSharedAttachments(noteID: noteID)
        }
        return try await remoteNotes.listAttachments(noteID: noteID)
    }

    private func downloadAttachments(
        noteID: UUID,
        attachments: [RemoteAttachmentSummary],
        shared: Bool
    ) async {
        await withTaskGroup(of: Void.self) { group in
            var iterator = attachments.makeIterator()
            var inFlight = 0

            func enqueueNext() {
                guard let summary = iterator.next() else { return }
                inFlight += 1
                group.addTask {
                    await self.downloadOneAttachment(
                        noteID: noteID,
                        summary: summary,
                        shared: shared
                    )
                }
            }

            let initial = min(Self.maxConcurrentAttachmentDownloads, attachments.count)
            for _ in 0 ..< initial {
                enqueueNext()
            }

            for await _ in group {
                inFlight -= 1
                enqueueNext()
            }
        }
    }

    private func downloadOneAttachment(
        noteID: UUID,
        summary: RemoteAttachmentSummary,
        shared: Bool
    ) async {
        let totalBytes = summary.sizeBytes
        emitHydrationProgress(
            AttachmentHydrationProgress(
                noteID: noteID,
                attachmentID: summary.attachmentID,
                bytesReceived: 0,
                totalBytes: totalBytes,
                state: .downloading
            )
        )

        do {
            let data: Data
            if shared {
                data = try await remoteNotes.readSharedAttachment(
                    noteID: noteID,
                    attachmentID: summary.attachmentID
                )
            } else {
                data = try await remoteNotes.readAttachment(
                    noteID: noteID,
                    attachmentID: summary.attachmentID
                )
            }

            try await localNotes.writeAttachmentFile(
                noteID: noteID,
                attachmentID: summary.attachmentID,
                ciphertext: data,
                etag: summary.etag
            )

            let received = UInt64(data.count)
            emitHydrationProgress(
                AttachmentHydrationProgress(
                    noteID: noteID,
                    attachmentID: summary.attachmentID,
                    bytesReceived: received,
                    totalBytes: totalBytes == 0 ? received : totalBytes,
                    state: .completed
                )
            )
        } catch {
            emitHydrationProgress(
                AttachmentHydrationProgress(
                    noteID: noteID,
                    attachmentID: summary.attachmentID,
                    bytesReceived: 0,
                    totalBytes: totalBytes,
                    state: .failed
                )
            )
        }
    }

    private func emitHydrationProgress(_ progress: AttachmentHydrationProgress) {
        hydrationProgressMulticaster.yield(progress)
    }
}

struct HydrationKey: Hashable, Sendable {
    let noteID: UUID
    let shared: Bool
}
