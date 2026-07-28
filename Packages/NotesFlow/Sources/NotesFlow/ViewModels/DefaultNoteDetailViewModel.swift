import Foundation
import NavigationProtocol
import NoteRepositoryProtocol
import Observation
import VaultSessionProtocol

@MainActor
public protocol NoteDetailViewModel: Observable {
    var noteID: UUID { get }
}

@MainActor
@Observable
public final class DefaultNoteDetailViewModel: NoteDetailViewModel {
    public let noteID: UUID
    private let noteRepository: any NoteRepository
    private let vaultSession: any VaultSessionProtocol
    private let navigator: any Navigating

    public init(
        noteID: UUID,
        noteRepository: any NoteRepository,
        vaultSession: any VaultSessionProtocol,
        navigator: any Navigating
    ) {
        self.noteID = noteID
        self.noteRepository = noteRepository
        self.vaultSession = vaultSession
        self.navigator = navigator
    }
}
