import Foundation
import NoteRepositoryProtocol

struct AttachmentIndexRow: Equatable, Sendable {
    let noteID: UUID
    let attachmentID: UUID
    let etag: String?
    let sizeBytes: UInt64
    let syncState: NoteSyncState

    init(
        noteID: UUID,
        attachmentID: UUID,
        etag: String? = nil,
        sizeBytes: UInt64,
        syncState: NoteSyncState
    ) {
        self.noteID = noteID
        self.attachmentID = attachmentID
        self.etag = etag
        self.sizeBytes = sizeBytes
        self.syncState = syncState
    }
}
