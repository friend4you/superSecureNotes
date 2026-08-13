import Foundation
import NoteRepositoryProtocol

extension NotesIndexStore {
    func upsertSharedNote(_ row: SharedNoteIndexRow) async throws {
        try withDatabase { database in
            try execute(
                """
                INSERT INTO shared_notes (
                    note_id, title, updated_at, etag, owner_email, owner_id, shared_at, body_etag
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(note_id) DO UPDATE SET
                    title = excluded.title,
                    updated_at = excluded.updated_at,
                    etag = excluded.etag,
                    owner_email = excluded.owner_email,
                    owner_id = excluded.owner_id,
                    shared_at = excluded.shared_at,
                    body_etag = excluded.body_etag
                """,
                on: database,
                bindings: [
                    .text(row.noteID.uuidString),
                    .text(row.title),
                    .int64(Int64(row.updatedAt)),
                    .text(row.etag),
                    .text(row.ownerEmail),
                    .text(row.ownerID.uuidString),
                    .int64(Int64(row.sharedAt.timeIntervalSince1970)),
                    row.bodyEtag.map(SQLiteBinding.text) ?? .text(""),
                ]
            )
        }
    }

    func fetchSharedNote(noteID: UUID) async throws -> SharedNoteIndexRow? {
        try withDatabase { database in
            let rows = try queryRows(
                """
                SELECT note_id, title, updated_at, etag, owner_email, owner_id, shared_at, body_etag
                FROM shared_notes
                WHERE note_id = ?
                """,
                bindings: [.text(noteID.uuidString)],
                on: database
            )
            return rows.first.map(Self.makeSharedRow)
        }
    }

    func listSharedSummaries() async throws -> [SharedNoteSummary] {
        try withDatabase { database in
            let rows = try queryRows(
                """
                SELECT note_id, title, updated_at, etag, owner_email, owner_id, shared_at, body_etag
                FROM shared_notes
                ORDER BY updated_at DESC
                """,
                on: database
            )
            return rows.map { Self.makeSharedRow($0).summary }
        }
    }

    func listSharedNoteIDs() async throws -> [UUID] {
        try withDatabase { database in
            let rows = try queryRows(
                "SELECT note_id FROM shared_notes",
                on: database
            )
            return rows.compactMap { row in
                UUID(uuidString: Self.textValue(row["note_id"]))
            }
        }
    }

    func deleteSharedNote(noteID: UUID) async throws {
        try withDatabase { database in
            try execute(
                "DELETE FROM shared_notes WHERE note_id = ?",
                on: database,
                bindings: [.text(noteID.uuidString)]
            )
        }
    }

    func updateSharedBodyEtag(noteID: UUID, bodyEtag: String?) async throws {
        try withDatabase { database in
            try execute(
                "UPDATE shared_notes SET body_etag = ? WHERE note_id = ?",
                on: database,
                bindings: [
                    bodyEtag.map(SQLiteBinding.text) ?? .text(""),
                    .text(noteID.uuidString),
                ]
            )
        }
    }

    func enqueueSharedDelete(noteID: UUID) async throws {
        try withDatabase { database in
            try execute(
                """
                INSERT INTO shared_delete_outbox (note_id) VALUES (?)
                ON CONFLICT(note_id) DO NOTHING
                """,
                on: database,
                bindings: [.text(noteID.uuidString)]
            )
        }
    }

    func listPendingSharedDeletes() async throws -> [UUID] {
        try withDatabase { database in
            let rows = try queryRows(
                "SELECT note_id FROM shared_delete_outbox",
                on: database
            )
            return rows.compactMap { row in
                UUID(uuidString: Self.textValue(row["note_id"]))
            }
        }
    }

    func removeSharedDeleteOutboxEntry(noteID: UUID) async throws {
        try withDatabase { database in
            try execute(
                "DELETE FROM shared_delete_outbox WHERE note_id = ?",
                on: database,
                bindings: [.text(noteID.uuidString)]
            )
        }
    }

    private static func makeSharedRow(_ row: [String: SQLiteValue]) -> SharedNoteIndexRow {
        let bodyEtagText = textValue(row["body_etag"])
        return SharedNoteIndexRow(
            noteID: UUID(uuidString: textValue(row["note_id"]))!,
            title: textValue(row["title"]),
            updatedAt: UInt64(int64Value(row["updated_at"])),
            etag: textValue(row["etag"]),
            ownerEmail: textValue(row["owner_email"]),
            ownerID: UUID(uuidString: textValue(row["owner_id"]))!,
            sharedAt: Date(timeIntervalSince1970: TimeInterval(int64Value(row["shared_at"]))),
            bodyEtag: bodyEtagText.isEmpty ? nil : bodyEtagText
        )
    }
}
