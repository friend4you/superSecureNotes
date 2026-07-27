import Foundation

public protocol NoteRepository: Sendable {
    func listNotes() async throws -> [NoteSummary]
    func readNote(noteID: UUID) async throws -> Data
    func writeNote(noteID: UUID, data: Data) async throws
    func deleteNote(noteID: UUID) async throws
}
