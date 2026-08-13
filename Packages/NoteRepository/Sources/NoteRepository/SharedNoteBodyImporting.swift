import Foundation
import NoteRepositoryProtocol

struct ImportedSharedNote: Equatable, Sendable {
    let note: SharedNote
    let bodyData: Data
}

protocol SharedNoteBodyImporting: Actor {
    func importSharedBody(noteID: UUID) async throws -> ImportedSharedNote
}
