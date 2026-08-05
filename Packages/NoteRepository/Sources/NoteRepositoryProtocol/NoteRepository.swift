import Foundation

public protocol NoteRepository: Sendable {
    func listNotes() async throws -> [NoteSummary]
    func readNote(noteID: UUID) async throws -> StoredNote
    func writeNote(_ note: StoredNote) async throws
    func deleteNote(noteID: UUID) async throws
    func shareNote(noteID: UUID, recipientEmail: String, wrappedFEK: Data) async throws
    func listSharedNotes() async throws -> [SharedNoteSummary]
    func readSharedNote(noteID: UUID) async throws -> SharedNote
}
