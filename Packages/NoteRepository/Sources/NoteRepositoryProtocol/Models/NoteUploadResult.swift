import Foundation

public struct NoteUploadResult: Equatable, Sendable {
    public let syncState: NoteSyncState
    public let updatedAt: UInt64
    public let etag: String?

    public init(syncState: NoteSyncState, updatedAt: UInt64, etag: String?) {
        self.syncState = syncState
        self.updatedAt = updatedAt
        self.etag = etag
    }
}
