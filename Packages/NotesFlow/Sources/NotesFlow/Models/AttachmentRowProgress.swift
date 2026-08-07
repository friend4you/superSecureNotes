import Foundation
import NoteRepositoryProtocol

/// Per-attachment download progress for NotesFlow UI rows.
public struct AttachmentRowProgress: Equatable, Sendable {
    public let bytesReceived: UInt64
    public let totalBytes: UInt64
    public let state: AttachmentHydrationProgress.State

    public init(
        bytesReceived: UInt64,
        totalBytes: UInt64,
        state: AttachmentHydrationProgress.State
    ) {
        self.bytesReceived = bytesReceived
        self.totalBytes = totalBytes
        self.state = state
    }

    public init(_ progress: AttachmentHydrationProgress) {
        self.bytesReceived = progress.bytesReceived
        self.totalBytes = progress.totalBytes
        self.state = progress.state
    }

    public var fractionCompleted: Double {
        guard totalBytes > 0 else { return state == .completed ? 1 : 0 }
        return min(1, Double(bytesReceived) / Double(totalBytes))
    }
}
