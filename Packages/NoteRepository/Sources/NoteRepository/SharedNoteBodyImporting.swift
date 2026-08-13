import Foundation
import NoteRepositoryProtocol

protocol SharedNoteBodyImporting: Actor {
    func importSharedBody(noteID: UUID) async throws -> SharedNote
}
