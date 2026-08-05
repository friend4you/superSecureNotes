import Foundation
import SecureCrypto

public struct SharedNote: Equatable, Sendable {
    public let noteID: UUID
    public let metadata: NoteMetadata
    public let recipientWrappedFEK: Data
    public let encryptedPayload: Data

    public init(
        noteID: UUID,
        metadata: NoteMetadata,
        recipientWrappedFEK: Data,
        encryptedPayload: Data
    ) {
        self.noteID = noteID
        self.metadata = metadata
        self.recipientWrappedFEK = recipientWrappedFEK
        self.encryptedPayload = encryptedPayload
    }
}
