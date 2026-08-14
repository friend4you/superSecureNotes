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
    func pullRemoteSharedCatalog() async throws
    func pullCatalogIfLocalVaultMissing() async throws -> Data?
}

public protocol NoteSyncing: Actor, VaultHeaderUploadScheduling, VaultHeaderUploading, NoteCatalogPulling {
    nonisolated var syncOutcomes: AsyncStream<NoteSyncOutcome> { get }
    nonisolated var attachmentHydrationProgress: AsyncStream<AttachmentHydrationProgress> { get }
    func flushPending() async
    func pullVaultHeaderIfLocalMissing() async throws -> Data?
    func pullRemoteNotesCatalog() async throws
    func pullRemoteSharedCatalog() async throws
    func pullCatalogIfLocalVaultMissing() async throws -> Data?
    func uploadVaultHeaderOrThrow(_ header: Data) async throws
    nonisolated func scheduleFlush()
    func reconcileNotesCatalog() async
    func reconcileAttachments(noteID: UUID) async
    func hydrateAttachments(noteID: UUID) async
    func hydrateSharedAttachments(noteID: UUID) async
    func retryAttachment(noteID: UUID, attachmentID: UUID) async
    func retrySharedAttachment(noteID: UUID, attachmentID: UUID) async
}

extension NoteSyncing {
    public func pullRemoteSharedCatalog() async throws {}

    public nonisolated var attachmentHydrationProgress: AsyncStream<AttachmentHydrationProgress> {
        AsyncStream { $0.finish() }
    }

    public func reconcileNotesCatalog() async {}

    public func reconcileAttachments(noteID: UUID) async {
        _ = noteID
    }

    public func hydrateAttachments(noteID: UUID) async {
        await reconcileAttachments(noteID: noteID)
    }

    public func hydrateSharedAttachments(noteID: UUID) async {
        _ = noteID
    }

    public func retryAttachment(noteID: UUID, attachmentID: UUID) async {
        _ = noteID
        _ = attachmentID
    }

    public func retrySharedAttachment(noteID: UUID, attachmentID: UUID) async {
        _ = noteID
        _ = attachmentID
    }
}
