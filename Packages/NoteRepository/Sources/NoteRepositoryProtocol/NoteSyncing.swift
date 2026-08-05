import Foundation

public protocol VaultHeaderUploadScheduling: Sendable {
    func scheduleVaultHeaderUpload(_ header: Data)
}

public protocol VaultHeaderUploading: Sendable {
    func uploadVaultHeaderOrThrow(_ header: Data) async throws
}

public struct NoOpVaultHeaderUploadScheduler: VaultHeaderUploadScheduling {
    public init() {}

    public func scheduleVaultHeaderUpload(_ header: Data) {}
}

public protocol NoteCatalogPulling: Sendable {
    func pullVaultHeaderIfLocalMissing() async throws -> Data?
    func pullRemoteNotesCatalog() async throws
    func pullCatalogIfLocalVaultMissing() async throws -> Data?
}

public protocol NoteSyncing: Actor, VaultHeaderUploadScheduling, VaultHeaderUploading, NoteCatalogPulling {
    nonisolated var syncOutcomes: AsyncStream<NoteSyncOutcome> { get }
    func flushPending() async
    func pullVaultHeaderIfLocalMissing() async throws -> Data?
    func pullRemoteNotesCatalog() async throws
    func pullCatalogIfLocalVaultMissing() async throws -> Data?
    func uploadVaultHeaderOrThrow(_ header: Data) async throws
    nonisolated func scheduleFlush()
}
