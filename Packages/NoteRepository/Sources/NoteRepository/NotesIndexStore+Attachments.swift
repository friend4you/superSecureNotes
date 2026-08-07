import Foundation
import NoteRepositoryProtocol

extension NotesIndexStore {
    func upsertAttachment(_ row: AttachmentIndexRow) async throws {
        try withDatabase { database in
            try execute(
                """
                INSERT INTO attachments (
                    note_id, attachment_id, etag, size_bytes, sync_state
                ) VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(note_id, attachment_id) DO UPDATE SET
                    etag = excluded.etag,
                    size_bytes = excluded.size_bytes,
                    sync_state = excluded.sync_state
                """,
                on: database,
                bindings: [
                    .text(row.noteID.uuidString),
                    .text(row.attachmentID.uuidString),
                    row.etag.map(SQLiteBinding.text) ?? .text(""),
                    .int64(Int64(row.sizeBytes)),
                    .text(row.syncState.rawValue),
                ]
            )
        }
    }

    func fetchAttachment(noteID: UUID, attachmentID: UUID) async throws -> AttachmentIndexRow? {
        try withDatabase { database in
            let rows = try queryRows(
                """
                SELECT note_id, attachment_id, etag, size_bytes, sync_state
                FROM attachments
                WHERE note_id = ? AND attachment_id = ?
                """,
                bindings: [
                    .text(noteID.uuidString),
                    .text(attachmentID.uuidString),
                ],
                on: database
            )
            return rows.first.map(Self.makeAttachmentRow)
        }
    }

    func listAttachments(noteID: UUID) async throws -> [AttachmentIndexRow] {
        try withDatabase { database in
            let rows = try queryRows(
                """
                SELECT note_id, attachment_id, etag, size_bytes, sync_state
                FROM attachments
                WHERE note_id = ?
                ORDER BY attachment_id ASC
                """,
                bindings: [.text(noteID.uuidString)],
                on: database
            )
            return rows.map(Self.makeAttachmentRow)
        }
    }

    func deleteAttachment(noteID: UUID, attachmentID: UUID) async throws {
        try withDatabase { database in
            try execute(
                """
                DELETE FROM attachments
                WHERE note_id = ? AND attachment_id = ?
                """,
                on: database,
                bindings: [
                    .text(noteID.uuidString),
                    .text(attachmentID.uuidString),
                ]
            )
        }
    }

    func deleteAttachments(noteID: UUID) async throws {
        try withDatabase { database in
            try execute(
                "DELETE FROM attachments WHERE note_id = ?",
                on: database,
                bindings: [.text(noteID.uuidString)]
            )
        }
    }

    private static func makeAttachmentRow(_ row: [String: SQLiteValue]) -> AttachmentIndexRow {
        let etagText = textValue(row["etag"])
        return AttachmentIndexRow(
            noteID: UUID(uuidString: textValue(row["note_id"]))!,
            attachmentID: UUID(uuidString: textValue(row["attachment_id"]))!,
            etag: etagText.isEmpty ? nil : etagText,
            sizeBytes: UInt64(int64Value(row["size_bytes"])),
            syncState: NoteSyncState(rawValue: textValue(row["sync_state"])) ?? .pendingSync
        )
    }
}
