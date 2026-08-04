import SecureCrypto
import XCTest

@testable import NoteRepositoryProtocol

final class StoredNoteTests: XCTestCase {
    func testNoteSyncStateCasesAreEquatable() {
        XCTAssertEqual(NoteSyncState.pendingSync, .pendingSync)
        XCTAssertEqual(NoteSyncState.synced, .synced)
        XCTAssertEqual(NoteSyncState.pendingDelete, .pendingDelete)
        XCTAssertNotEqual(NoteSyncState.pendingSync, .synced)
        XCTAssertNotEqual(NoteSyncState.pendingDelete, .synced)
        XCTAssertNotEqual(NoteSyncState.pendingDelete, .pendingSync)
    }

    func testStoredNoteIsEquatable() {
        let noteID = UUID(uuidString: "550E8400-E29B-41D4-A716-446655440000")!
        let metadata = NoteMetadata(
            noteID: noteID,
            title: "My note",
            createdAt: 1_700_000_000,
            updatedAt: 1_700_000_100,
            attachmentCount: 1,
            attachmentsTotalSize: 42
        )
        let wrappedFEK = Data([0x01, 0x02])
        let encryptedPayload = Data([0xAA, 0xBB])

        let first = StoredNote(
            metadata: metadata,
            wrappedFEK: wrappedFEK,
            encryptedPayload: encryptedPayload,
            syncState: .pendingSync
        )
        let second = StoredNote(
            metadata: metadata,
            wrappedFEK: wrappedFEK,
            encryptedPayload: encryptedPayload,
            syncState: .pendingSync
        )

        XCTAssertEqual(first, second)
    }

    func testStoredNoteWithDifferentSyncStateIsNotEqual() {
        let noteID = UUID(uuidString: "550E8400-E29B-41D4-A716-446655440000")!
        let metadata = NoteMetadata(
            noteID: noteID,
            title: "My note",
            createdAt: 1_700_000_000,
            updatedAt: 1_700_000_100,
            attachmentCount: 0,
            attachmentsTotalSize: 0
        )

        let pending = StoredNote(
            metadata: metadata,
            wrappedFEK: Data([0x01]),
            encryptedPayload: Data([0x02]),
            syncState: .pendingSync
        )
        let synced = StoredNote(
            metadata: metadata,
            wrappedFEK: Data([0x01]),
            encryptedPayload: Data([0x02]),
            syncState: .synced
        )

        XCTAssertNotEqual(pending, synced)
    }
}
