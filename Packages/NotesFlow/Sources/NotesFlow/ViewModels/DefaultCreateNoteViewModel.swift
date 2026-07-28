import NavigationProtocol
import NoteRepositoryProtocol
import Observation
import VaultSessionProtocol

@MainActor
public protocol CreateNoteViewModel: Observable {}

@MainActor
@Observable
public final class DefaultCreateNoteViewModel: CreateNoteViewModel {
    private let noteRepository: any NoteRepository
    private let vaultSession: any VaultSessionProtocol
    private let navigator: any Navigating

    public init(
        noteRepository: any NoteRepository,
        vaultSession: any VaultSessionProtocol,
        navigator: any Navigating
    ) {
        self.noteRepository = noteRepository
        self.vaultSession = vaultSession
        self.navigator = navigator
    }
}
