import Foundation

extension NotesIndexStore {
    func fetchAttachmentUploadSession(
        noteID: UUID,
        attachmentID: UUID
    ) async throws -> AttachmentUploadSessionRecord? {
        try withDatabase { database in
            let rows = try queryRows(
                """
                SELECT note_id, attachment_id, upload_id, wire_size, chunk_size, total_chunks,
                       completed_chunk_indices, if_match
                FROM attachment_upload_sessions
                WHERE note_id = ? AND attachment_id = ?
                """,
                bindings: [
                    .text(noteID.uuidString),
                    .text(attachmentID.uuidString),
                ],
                on: database
            )
            return rows.first.map(Self.makeAttachmentUploadSessionRecord)
        }
    }

    func upsertAttachmentUploadSession(_ record: AttachmentUploadSessionRecord) async throws {
        try withDatabase { database in
            try execute(
                """
                INSERT INTO attachment_upload_sessions (
                    note_id, attachment_id, upload_id, wire_size, chunk_size, total_chunks,
                    completed_chunk_indices, if_match
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(note_id, attachment_id) DO UPDATE SET
                    upload_id = excluded.upload_id,
                    wire_size = excluded.wire_size,
                    chunk_size = excluded.chunk_size,
                    total_chunks = excluded.total_chunks,
                    completed_chunk_indices = excluded.completed_chunk_indices,
                    if_match = excluded.if_match
                """,
                on: database,
                bindings: Self.attachmentUploadSessionBindings(record)
            )
        }
    }

    func markAttachmentUploadChunkCompleted(
        noteID: UUID,
        attachmentID: UUID,
        chunkIndex: Int
    ) async throws {
        guard var record = try await fetchAttachmentUploadSession(
            noteID: noteID,
            attachmentID: attachmentID
        ) else {
            return
        }
        record.completedChunkIndices.insert(chunkIndex)
        try await upsertAttachmentUploadSession(record)
    }

    func deleteAttachmentUploadSession(noteID: UUID, attachmentID: UUID) async throws {
        try withDatabase { database in
            try execute(
                """
                DELETE FROM attachment_upload_sessions
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

    func deleteAttachmentUploadSessions(noteID: UUID) async throws {
        try withDatabase { database in
            try execute(
                "DELETE FROM attachment_upload_sessions WHERE note_id = ?",
                on: database,
                bindings: [.text(noteID.uuidString)]
            )
        }
    }

    static func makeAttachmentUploadSessionRecord(
        _ row: [String: SQLiteValue]
    ) -> AttachmentUploadSessionRecord {
        let ifMatchText = textValue(row["if_match"])
        return AttachmentUploadSessionRecord(
            noteID: UUID(uuidString: textValue(row["note_id"]))!,
            attachmentID: UUID(uuidString: textValue(row["attachment_id"]))!,
            uploadID: UUID(uuidString: textValue(row["upload_id"]))!,
            wireSize: Int(int64Value(row["wire_size"])),
            chunkSize: Int(int64Value(row["chunk_size"])),
            totalChunks: Int(int64Value(row["total_chunks"])),
            completedChunkIndices: parseCompletedChunkIndices(textValue(row["completed_chunk_indices"])),
            ifMatch: ifMatchText.isEmpty ? nil : ifMatchText
        )
    }

    static func attachmentUploadSessionBindings(
        _ record: AttachmentUploadSessionRecord
    ) -> [SQLiteBinding] {
        [
            .text(record.noteID.uuidString),
            .text(record.attachmentID.uuidString),
            .text(record.uploadID.uuidString),
            .int64(Int64(record.wireSize)),
            .int64(Int64(record.chunkSize)),
            .int64(Int64(record.totalChunks)),
            .text(serializeCompletedChunkIndices(record.completedChunkIndices)),
            record.ifMatch.map(SQLiteBinding.text) ?? .text(""),
        ]
    }
}
