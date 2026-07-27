import Foundation

public struct NoteSummary: Equatable, Sendable {
    public let noteID: UUID
    public let title: String
    public let updatedAt: UInt64

    public init(noteID: UUID, title: String, updatedAt: UInt64) {
        self.noteID = noteID
        self.title = title
        self.updatedAt = updatedAt
    }
}
