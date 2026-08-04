import Foundation

public enum NoteSyncOutcome: Equatable, Sendable {
    case uploaded(noteID: UUID, syncState: NoteSyncState, updatedAt: UInt64, etag: String?)
    case uploadFailed(noteID: UUID)
}
