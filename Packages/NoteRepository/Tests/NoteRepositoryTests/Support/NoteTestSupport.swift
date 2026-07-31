import Foundation
import NoteRepositoryProtocol
import SecureCrypto

enum NoteTestSupport {
    static let databasePassphrase = Data([0x01, 0x02, 0x03])

    static func openDatabase(_ repository: any NoteRepository) async throws {
        try await repository.openDatabase(passphrase: databasePassphrase)
    }

    static func makeSampleStoredNote(
        noteID: UUID,
        title: String,
        updatedAt: UInt64 = 1_700_000_100,
        syncState: NoteSyncState = .pendingSync
    ) -> StoredNote {
        StoredNote(
            metadata: NoteMetadata(
                noteID: noteID,
                title: title,
                createdAt: 1_700_000_000,
                updatedAt: updatedAt,
                attachmentCount: 0,
                attachmentsTotalSize: 0
            ),
            wrappedFEK: Data(repeating: 0xAB, count: 60),
            encryptedPayload: Data(repeating: 0xCD, count: 128),
            syncState: syncState
        )
    }

    static func makeSampleWireNote(
        noteID: UUID,
        title: String,
        updatedAt: UInt64 = 1_700_000_100
    ) throws -> Data {
        try assembleNoteFile(
            metadata: NoteMetadata(
                noteID: noteID,
                title: title,
                createdAt: 1_700_000_000,
                updatedAt: updatedAt,
                attachmentCount: 0,
                attachmentsTotalSize: 0
            ),
            wrappedFEK: Data(repeating: 0xAB, count: 60),
            encryptedPayload: Data(repeating: 0xCD, count: 128)
        )
    }
}
