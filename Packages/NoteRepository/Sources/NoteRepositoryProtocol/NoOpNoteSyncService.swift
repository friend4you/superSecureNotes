import Foundation

public actor NoOpNoteSyncService: NoteSyncing {
    public nonisolated let syncOutcomes: AsyncStream<NoteSyncOutcome> = AsyncStream { $0.finish() }

    public init() {}

    public func flushPending() async {}

    public func pullVaultHeaderIfLocalMissing() async throws -> Data? {
        nil
    }

    public func pullRemoteNotesCatalog() async throws {}

    public func pullRemoteSharedCatalog() async throws {}

    public func pullCatalogIfLocalVaultMissing() async throws -> Data? {
        nil
    }

    public func uploadVaultHeaderOrThrow(_ header: Data) async throws {}

    public nonisolated func scheduleFlush() {}

    public func reconcileNotesCatalog() async {}

    public func reconcileAttachments(noteID: UUID) async {
        _ = noteID
    }

    public nonisolated func scheduleVaultHeaderUpload(_ header: Data) {}
}
