import Foundation
import NoteRepositoryProtocol
import SQLCipher
import SecureCrypto

@testable import NoteRepository

enum NoteTestSupport {
    static let databasePassphrase = Data([0x01, 0x02, 0x03])

    static func openIndexStore(_ store: NotesIndexStore) async throws {
        try await store.open(passphrase: databasePassphrase)
    }

    static func makeLocalRepository(
        notesRootURL: URL
    ) -> (NotesIndexStore, LocalNoteRepository) {
        let store = NotesIndexStore(notesDirectoryURL: notesRootURL)
        let repository = LocalNoteRepository(
            notesIndexStore: store,
            notesRootURL: notesRootURL
        )
        return (store, repository)
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

    static func makeStoredNoteWithWireBlobSize(
        noteID: UUID,
        title: String,
        wireBlobSize: Int,
        updatedAt: UInt64 = 1_700_000_100,
        syncState: NoteSyncState = .pendingSync
    ) throws -> StoredNote {
        let metadata = NoteMetadata(
            noteID: noteID,
            title: title,
            createdAt: 1_700_000_000,
            updatedAt: updatedAt,
            attachmentCount: 0,
            attachmentsTotalSize: 0
        )
        let wrappedFEK = Data(repeating: 0xAB, count: 60)
        let baseWireSize = try assembleNoteFile(
            metadata: metadata,
            wrappedFEK: wrappedFEK,
            encryptedPayload: Data()
        ).count
        let payloadSize = wireBlobSize - baseWireSize
        precondition(payloadSize >= 0, "wireBlobSize must fit metadata and wrapped FEK overhead")
        let encryptedPayload = Data(repeating: 0xCD, count: payloadSize)
        let actualWireSize = try assembleNoteFile(
            metadata: metadata,
            wrappedFEK: wrappedFEK,
            encryptedPayload: encryptedPayload
        ).count
        precondition(actualWireSize == wireBlobSize, "expected wire blob size \(wireBlobSize), got \(actualWireSize)")
        return StoredNote(
            metadata: metadata,
            wrappedFEK: wrappedFEK,
            encryptedPayload: encryptedPayload,
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

    static func seedLegacyIndexDatabase(
        at notesDirectoryURL: URL,
        passphrase: Data,
        noteID: UUID,
        title: String
    ) throws {
        try FileManager.default.createDirectory(
            at: notesDirectoryURL,
            withIntermediateDirectories: true
        )
        let databaseURL = notesDirectoryURL.appendingPathComponent("notes.db")
        var pointer: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &pointer) == SQLITE_OK, let pointer else {
            throw NotesIndexStoreError.openFailed(code: SQLITE_ERROR)
        }
        defer { sqlite3_close(pointer) }

        let hexPassphrase = passphrase.map { String(format: "%02x", $0) }.joined()
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(
            pointer,
            "PRAGMA key = \"x'\(hexPassphrase)'\"",
            nil,
            nil,
            &error
        ) == SQLITE_OK else {
            throw NotesIndexStoreError.sqliteError(
                message: error.map { String(cString: $0) } ?? "PRAGMA key failed"
            )
        }

        let createLegacyTable = """
            CREATE TABLE notes (
                note_id TEXT PRIMARY KEY NOT NULL,
                title TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                attachment_count INTEGER NOT NULL,
                attachments_total_size INTEGER NOT NULL,
                wrapped_fek BLOB NOT NULL,
                sync_state TEXT NOT NULL CHECK (sync_state IN ('pendingSync', 'synced'))
            )
            """
        guard sqlite3_exec(pointer, createLegacyTable, nil, nil, &error) == SQLITE_OK else {
            throw NotesIndexStoreError.sqliteError(
                message: error.map { String(cString: $0) } ?? "create table failed"
            )
        }

        let insert = """
            INSERT INTO notes (
                note_id, title, created_at, updated_at,
                attachment_count, attachments_total_size, wrapped_fek, sync_state
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(pointer, insert, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw NotesIndexStoreError.sqliteError(message: "prepare insert failed")
        }
        defer { sqlite3_finalize(statement) }

        let wrappedFEK = Data(repeating: 0xAB, count: 60)
        sqlite3_bind_text(statement, 1, noteID.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(statement, 2, title, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_int64(statement, 3, 1_700_000_000)
        sqlite3_bind_int64(statement, 4, 1_700_000_100)
        sqlite3_bind_int(statement, 5, 0)
        sqlite3_bind_int64(statement, 6, 0)
        _ = wrappedFEK.withUnsafeBytes { buffer in
            sqlite3_bind_blob(
                statement,
                7,
                buffer.baseAddress,
                Int32(buffer.count),
                unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            )
        }
        sqlite3_bind_text(statement, 8, "synced", -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw NotesIndexStoreError.sqliteError(message: "insert failed")
        }
    }
}
