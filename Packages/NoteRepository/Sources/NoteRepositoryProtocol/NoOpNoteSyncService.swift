import Foundation

public actor NoOpNoteSyncService: NoteSyncing {
    public nonisolated let syncOutcomes: AsyncStream<NoteSyncOutcome> = AsyncStream { $0.finish() }

    public init() {}

    public func flushPending() async {}

    public func pullCatalogIfLocalVaultMissing() async throws -> Data? {
        nil
    }

    public nonisolated func scheduleFlush() {}

    public nonisolated func scheduleVaultHeaderUpload(_ header: Data) {}
}
