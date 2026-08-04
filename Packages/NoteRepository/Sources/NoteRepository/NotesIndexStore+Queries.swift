import Foundation
import NoteRepositoryProtocol

extension NotesIndexStore {
    func upsertNote(_ row: NoteIndexRow) async throws {
        try withDatabase { database in
            try execute(
                """
                INSERT INTO notes (
                    note_id, title, created_at, updated_at,
                    attachment_count, attachments_total_size, wrapped_fek, sync_state, etag
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(note_id) DO UPDATE SET
                    title = excluded.title,
                    created_at = excluded.created_at,
                    updated_at = excluded.updated_at,
                    attachment_count = excluded.attachment_count,
                    attachments_total_size = excluded.attachments_total_size,
                    wrapped_fek = excluded.wrapped_fek,
                    sync_state = excluded.sync_state,
                    etag = excluded.etag
                """,
                on: database,
                bindings: [
                    .text(row.noteID.uuidString),
                    .text(row.title),
                    .int64(Int64(row.createdAt)),
                    .int64(Int64(row.updatedAt)),
                    .int32(Int32(row.attachmentCount)),
                    .int64(Int64(row.attachmentsTotalSize)),
                    .blob(row.wrappedFEK),
                    .text(row.syncState.rawValue),
                    row.etag.map(SQLiteBinding.text) ?? .text(""),
                ]
            )
        }
    }

    func fetchNote(noteID: UUID) async throws -> NoteIndexRow? {
        try withDatabase { database in
            let rows = try queryRows(
                """
                SELECT note_id, title, created_at, updated_at,
                       attachment_count, attachments_total_size, wrapped_fek, sync_state, etag
                FROM notes
                WHERE note_id = ?
                """,
                bindings: [.text(noteID.uuidString)],
                on: database
            )
            return rows.first.map(Self.makeRow)
        }
    }

    func listSummaries() async throws -> [NoteSummary] {
        try withDatabase { database in
            let rows = try queryRows(
                """
                SELECT note_id, title, updated_at, sync_state
                FROM notes
                ORDER BY updated_at DESC
                """,
                on: database
            )
            return rows.map { row in
                NoteSummary(
                    noteID: UUID(uuidString: Self.textValue(row["note_id"]))!,
                    title: Self.textValue(row["title"]),
                    updatedAt: UInt64(Self.int64Value(row["updated_at"])),
                    syncState: NoteSyncState(rawValue: Self.textValue(row["sync_state"])) ?? .pendingSync
                )
            }
        }
    }

    func listRows(withSyncState syncState: NoteSyncState) async throws -> [NoteIndexRow] {
        try withDatabase { database in
            let rows = try queryRows(
                """
                SELECT note_id, title, created_at, updated_at,
                       attachment_count, attachments_total_size, wrapped_fek, sync_state, etag
                FROM notes
                WHERE sync_state = ?
                ORDER BY updated_at ASC
                """,
                bindings: [.text(syncState.rawValue)],
                on: database
            )
            return rows.map(Self.makeRow)
        }
    }

    func deleteNote(noteID: UUID) async throws {
        try withDatabase { database in
            try execute(
                "DELETE FROM notes WHERE note_id = ?",
                on: database,
                bindings: [.text(noteID.uuidString)]
            )
        }
    }

    private static func makeRow(_ row: [String: SQLiteValue]) -> NoteIndexRow {
        let etagText = NotesIndexStore.textValue(row["etag"])
        return NoteIndexRow(
            noteID: UUID(uuidString: NotesIndexStore.textValue(row["note_id"]))!,
            title: NotesIndexStore.textValue(row["title"]),
            createdAt: UInt64(NotesIndexStore.int64Value(row["created_at"])),
            updatedAt: UInt64(NotesIndexStore.int64Value(row["updated_at"])),
            attachmentCount: UInt32(NotesIndexStore.int64Value(row["attachment_count"])),
            attachmentsTotalSize: UInt64(NotesIndexStore.int64Value(row["attachments_total_size"])),
            wrappedFEK: NotesIndexStore.blobValue(row["wrapped_fek"]),
            syncState: NoteSyncState(rawValue: NotesIndexStore.textValue(row["sync_state"])) ?? .pendingSync,
            etag: etagText.isEmpty ? nil : etagText
        )
    }
}
