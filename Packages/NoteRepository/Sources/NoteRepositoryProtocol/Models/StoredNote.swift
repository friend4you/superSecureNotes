import Foundation
import SecureCrypto

public struct StoredNote: Equatable, Sendable {
    public let metadata: NoteMetadata
    public let wrappedFEK: Data
    public let encryptedPayload: Data
    public let syncState: NoteSyncState
    /// Encrypted attachment file bytes keyed by attachment id (split storage). Empty for legacy notes.
    public let attachmentCiphertexts: [UUID: Data]

    public init(
        metadata: NoteMetadata,
        wrappedFEK: Data,
        encryptedPayload: Data,
        syncState: NoteSyncState,
        attachmentCiphertexts: [UUID: Data] = [:]
    ) {
        self.metadata = metadata
        self.wrappedFEK = wrappedFEK
        self.encryptedPayload = encryptedPayload
        self.syncState = syncState
        self.attachmentCiphertexts = attachmentCiphertexts
    }
}
