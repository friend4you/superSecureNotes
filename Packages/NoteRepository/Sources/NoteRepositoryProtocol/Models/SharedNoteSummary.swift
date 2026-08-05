import Foundation

public struct SharedNoteSummary: Equatable, Sendable {
    public let noteID: UUID
    public let title: String
    public let updatedAt: UInt64
    public let etag: String
    public let ownerEmail: String
    public let ownerID: UUID
    public let sharedAt: Date

    public init(
        noteID: UUID,
        title: String,
        updatedAt: UInt64,
        etag: String,
        ownerEmail: String,
        ownerID: UUID,
        sharedAt: Date
    ) {
        self.noteID = noteID
        self.title = title
        self.updatedAt = updatedAt
        self.etag = etag
        self.ownerEmail = ownerEmail
        self.ownerID = ownerID
        self.sharedAt = sharedAt
    }
}
