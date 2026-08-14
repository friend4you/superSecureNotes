import Foundation

public struct NoteUploadResult: Equatable, Sendable {
    public let syncState: NoteSyncState
    public let updatedAt: UInt64
    public let etag: String?
    public let uploadedAttachmentEtags: [UUID: String]

    public init(
        syncState: NoteSyncState,
        updatedAt: UInt64,
        etag: String?,
        uploadedAttachmentEtags: [UUID: String] = [:]
    ) {
        self.syncState = syncState
        self.updatedAt = updatedAt
        self.etag = etag
        self.uploadedAttachmentEtags = uploadedAttachmentEtags
    }
}
