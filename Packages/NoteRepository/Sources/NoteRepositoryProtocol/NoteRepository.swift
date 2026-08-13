import Foundation

public protocol NoteRepository: Sendable {
    func listNotes() async throws -> [NoteSummary]
    func readNote(noteID: UUID) async throws -> StoredNote
    func writeNote(_ note: StoredNote) async throws
    func deleteNote(noteID: UUID) async throws
    func shareNote(noteID: UUID, recipientEmail: String, wrappedFEK: Data) async throws
    func listSharedNotes() async throws -> [SharedNoteSummary]
    func fetchSharedNoteSummary(noteID: UUID) async throws -> SharedNoteSummary?
    func readSharedNote(noteID: UUID) async throws -> SharedNote
    func readSharedAttachmentCiphertext(noteID: UUID, attachmentID: UUID) async throws -> Data?
    func loadSharedAttachmentCiphertexts(noteID: UUID) async throws -> [UUID: Data]
    func deleteSharedNote(noteID: UUID) async throws
}

public extension NoteRepository {
    func fetchSharedNoteSummary(noteID: UUID) async throws -> SharedNoteSummary? {
        try await listSharedNotes().first { $0.noteID == noteID }
    }

    func readSharedAttachmentCiphertext(noteID: UUID, attachmentID: UUID) async throws -> Data? {
        nil
    }

    func loadSharedAttachmentCiphertexts(noteID: UUID) async throws -> [UUID: Data] {
        [:]
    }
}
