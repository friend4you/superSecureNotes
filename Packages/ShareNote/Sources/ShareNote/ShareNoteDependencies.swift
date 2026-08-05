import Foundation
import NavigationProtocol
import NoteRepositoryProtocol
import VaultRepositoryProtocol
import VaultSessionProtocol

@MainActor
public final class ShareNoteDependencies: ShareNoteDependencyProviding {
    private let navigator: any Navigating
    private let noteRepository: any NoteRepository
    private let vaultRepository: any VaultRepository
    private let vaultSession: any VaultSessionProtocol

    public init(
        navigator: any Navigating,
        noteRepository: any NoteRepository,
        vaultRepository: any VaultRepository,
        vaultSession: any VaultSessionProtocol
    ) {
        self.navigator = navigator
        self.noteRepository = noteRepository
        self.vaultRepository = vaultRepository
        self.vaultSession = vaultSession
    }

    public func makeShareNoteViewModel(noteID: UUID) -> DefaultShareNoteViewModel {
        DefaultShareNoteViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            vaultRepository: vaultRepository,
            vaultSession: vaultSession,
            navigator: navigator
        )
    }
}
