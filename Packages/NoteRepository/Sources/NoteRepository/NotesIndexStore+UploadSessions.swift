import Foundation

extension NotesIndexStore {
    func fetchUploadSession(noteID: UUID) async throws -> NoteUploadSessionRecord? {
        try withDatabase { database in
            let rows = try queryRows(
                """
                SELECT note_id, upload_id, wire_size, chunk_size, total_chunks,
                       completed_chunk_indices, if_match
                FROM note_upload_sessions
                WHERE note_id = ?
                """,
                bindings: [.text(noteID.uuidString)],
                on: database
            )
            return rows.first.map(Self.makeUploadSessionRecord)
        }
    }

    func upsertUploadSession(_ record: NoteUploadSessionRecord) async throws {
        try withDatabase { database in
            try execute(
                """
                INSERT INTO note_upload_sessions (
                    note_id, upload_id, wire_size, chunk_size, total_chunks,
                    completed_chunk_indices, if_match
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(note_id) DO UPDATE SET
                    upload_id = excluded.upload_id,
                    wire_size = excluded.wire_size,
                    chunk_size = excluded.chunk_size,
                    total_chunks = excluded.total_chunks,
                    completed_chunk_indices = excluded.completed_chunk_indices,
                    if_match = excluded.if_match
                """,
                on: database,
                bindings: Self.uploadSessionBindings(record)
            )
        }
    }

    func markUploadChunkCompleted(noteID: UUID, chunkIndex: Int) async throws {
        guard var record = try await fetchUploadSession(noteID: noteID) else {
            return
        }
        record.completedChunkIndices.insert(chunkIndex)
        try await upsertUploadSession(record)
    }

    func deleteUploadSession(noteID: UUID) async throws {
        try withDatabase { database in
            try execute(
                "DELETE FROM note_upload_sessions WHERE note_id = ?",
                on: database,
                bindings: [.text(noteID.uuidString)]
            )
        }
    }

    static func makeUploadSessionRecord(_ row: [String: SQLiteValue]) -> NoteUploadSessionRecord {
        let ifMatchText = textValue(row["if_match"])
        return NoteUploadSessionRecord(
            noteID: UUID(uuidString: textValue(row["note_id"]))!,
            uploadID: UUID(uuidString: textValue(row["upload_id"]))!,
            wireSize: Int(int64Value(row["wire_size"])),
            chunkSize: Int(int64Value(row["chunk_size"])),
            totalChunks: Int(int64Value(row["total_chunks"])),
            completedChunkIndices: parseCompletedChunkIndices(textValue(row["completed_chunk_indices"])),
            ifMatch: ifMatchText.isEmpty ? nil : ifMatchText
        )
    }

    static func uploadSessionBindings(_ record: NoteUploadSessionRecord) -> [SQLiteBinding] {
        [
            .text(record.noteID.uuidString),
            .text(record.uploadID.uuidString),
            .int64(Int64(record.wireSize)),
            .int64(Int64(record.chunkSize)),
            .int64(Int64(record.totalChunks)),
            .text(serializeCompletedChunkIndices(record.completedChunkIndices)),
            record.ifMatch.map(SQLiteBinding.text) ?? .text(""),
        ]
    }

    static func parseCompletedChunkIndices(_ text: String) -> Set<Int> {
        guard
            let data = text.data(using: .utf8),
            let indices = try? JSONSerialization.jsonObject(with: data) as? [Int]
        else {
            return []
        }
        return Set(indices)
    }

    static func serializeCompletedChunkIndices(_ indices: Set<Int>) -> String {
        let payload = indices.sorted()
        let data = try! JSONSerialization.data(withJSONObject: payload)
        return String(decoding: data, as: UTF8.self)
    }
}
