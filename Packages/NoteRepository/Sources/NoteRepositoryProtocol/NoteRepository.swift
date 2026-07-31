import Foundation

public protocol NoteRepository: Sendable {
    func listNotes() async throws -> [NoteSummary]
    func readNote(noteID: UUID) async throws -> StoredNote
    func writeNote(_ note: StoredNote) async throws
    func deleteNote(noteID: UUID) async throws
}
