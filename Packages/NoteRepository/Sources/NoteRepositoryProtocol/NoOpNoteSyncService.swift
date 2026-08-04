import Foundation

public actor NoOpNoteSyncService: NoteSyncing {
    public init() {}

    public func flushPending() async {}

    public func pullCatalogIfLocalVaultMissing() async throws -> Data? {
        nil
    }

    public nonisolated func scheduleVaultHeaderUpload(_ header: Data) {}
}
