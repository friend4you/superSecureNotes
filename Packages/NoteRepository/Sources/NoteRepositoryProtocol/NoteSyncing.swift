import Foundation

public protocol VaultHeaderUploadScheduling: Sendable {
    func scheduleVaultHeaderUpload(_ header: Data)
}

public struct NoOpVaultHeaderUploadScheduler: VaultHeaderUploadScheduling {
    public init() {}

    public func scheduleVaultHeaderUpload(_ header: Data) {}
}

public protocol NoteCatalogPulling: Sendable {
    func pullCatalogIfLocalVaultMissing() async throws -> Data?
}

public protocol NoteSyncing: Actor, VaultHeaderUploadScheduling, NoteCatalogPulling {
    func flushPending() async
}
