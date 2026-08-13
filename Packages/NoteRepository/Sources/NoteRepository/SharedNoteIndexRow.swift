import Foundation
import NoteRepositoryProtocol

struct SharedNoteIndexRow: Equatable, Sendable {
    let noteID: UUID
    let title: String
    let updatedAt: UInt64
    let etag: String
    let ownerEmail: String
    let ownerID: UUID
    let sharedAt: Date
    let bodyEtag: String?

    init(
        noteID: UUID,
        title: String,
        updatedAt: UInt64,
        etag: String,
        ownerEmail: String,
        ownerID: UUID,
        sharedAt: Date,
        bodyEtag: String? = nil
    ) {
        self.noteID = noteID
        self.title = title
        self.updatedAt = updatedAt
        self.etag = etag
        self.ownerEmail = ownerEmail
        self.ownerID = ownerID
        self.sharedAt = sharedAt
        self.bodyEtag = bodyEtag
    }

    init(summary: SharedNoteSummary, bodyEtag: String? = nil) {
        noteID = summary.noteID
        title = summary.title
        updatedAt = summary.updatedAt
        etag = summary.etag
        ownerEmail = summary.ownerEmail
        ownerID = summary.ownerID
        sharedAt = summary.sharedAt
        self.bodyEtag = bodyEtag
    }

    var summary: SharedNoteSummary {
        SharedNoteSummary(
            noteID: noteID,
            title: title,
            updatedAt: updatedAt,
            etag: etag,
            ownerEmail: ownerEmail,
            ownerID: ownerID,
            sharedAt: sharedAt
        )
    }
}
