import Foundation

public struct NoteSummary: Equatable, Sendable {
    public let noteID: UUID
    public let title: String
    public let updatedAt: UInt64
    public let syncState: NoteSyncState
    public let etag: String?

    public init(
        noteID: UUID,
        title: String,
        updatedAt: UInt64,
        syncState: NoteSyncState,
        etag: String? = nil
    ) {
        self.noteID = noteID
        self.title = title
        self.updatedAt = updatedAt
        self.syncState = syncState
        self.etag = etag
    }
}
