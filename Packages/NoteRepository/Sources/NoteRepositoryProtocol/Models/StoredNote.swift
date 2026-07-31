import Foundation
import SecureCrypto

public struct StoredNote: Equatable, Sendable {
    public let metadata: NoteMetadata
    public let wrappedFEK: Data
    public let encryptedPayload: Data
    public let syncState: NoteSyncState

    public init(
        metadata: NoteMetadata,
        wrappedFEK: Data,
        encryptedPayload: Data,
        syncState: NoteSyncState
    ) {
        self.metadata = metadata
        self.wrappedFEK = wrappedFEK
        self.encryptedPayload = encryptedPayload
        self.syncState = syncState
    }
}
