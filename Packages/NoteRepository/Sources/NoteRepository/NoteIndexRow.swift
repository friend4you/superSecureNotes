import Foundation
import NoteRepositoryProtocol
import SecureCrypto

struct NoteIndexRow: Equatable, Sendable {
    let noteID: UUID
    let title: String
    let createdAt: UInt64
    let updatedAt: UInt64
    let attachmentCount: UInt32
    let attachmentsTotalSize: UInt64
    let wrappedFEK: Data
    let syncState: NoteSyncState

    init(storedNote: StoredNote) {
        noteID = storedNote.metadata.noteID
        title = storedNote.metadata.title
        createdAt = storedNote.metadata.createdAt
        updatedAt = storedNote.metadata.updatedAt
        attachmentCount = storedNote.metadata.attachmentCount
        attachmentsTotalSize = storedNote.metadata.attachmentsTotalSize
        wrappedFEK = storedNote.wrappedFEK
        syncState = storedNote.syncState
    }

    init(
        noteID: UUID,
        title: String,
        createdAt: UInt64,
        updatedAt: UInt64,
        attachmentCount: UInt32,
        attachmentsTotalSize: UInt64,
        wrappedFEK: Data,
        syncState: NoteSyncState
    ) {
        self.noteID = noteID
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.attachmentCount = attachmentCount
        self.attachmentsTotalSize = attachmentsTotalSize
        self.wrappedFEK = wrappedFEK
        self.syncState = syncState
    }

    var metadata: NoteMetadata {
        NoteMetadata(
            noteID: noteID,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
            attachmentCount: attachmentCount,
            attachmentsTotalSize: attachmentsTotalSize
        )
    }

    var summary: NoteSummary {
        NoteSummary(noteID: noteID, title: title, updatedAt: updatedAt, syncState: syncState)
    }
}
