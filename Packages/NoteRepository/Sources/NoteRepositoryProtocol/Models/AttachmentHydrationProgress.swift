import Foundation

public struct AttachmentHydrationProgress: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        case downloading
        case completed
        case failed
    }

    public let noteID: UUID
    public let attachmentID: UUID
    public let bytesReceived: UInt64
    public let totalBytes: UInt64
    public let state: State

    public init(
        noteID: UUID,
        attachmentID: UUID,
        bytesReceived: UInt64,
        totalBytes: UInt64,
        state: State
    ) {
        self.noteID = noteID
        self.attachmentID = attachmentID
        self.bytesReceived = bytesReceived
        self.totalBytes = totalBytes
        self.state = state
    }
}
