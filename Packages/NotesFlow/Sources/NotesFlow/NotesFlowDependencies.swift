import AuthRepositoryProtocol
import CredentialStoreProtocol
import Foundation
import NavigationProtocol
import NoteRepositoryProtocol
import NotesFlowRoutes
import VaultSessionProtocol

@MainActor
public final class NotesFlowDependencies: NotesDependencyProviding {
    private let authRepository: any AuthRepository
    private let vaultSession: any VaultSessionProtocol
    private let navigator: any Navigating
    internal let noteRepository: any NoteRepository
    private let credentialStore: any CredentialStore
    private var noteListViewModel: DefaultNoteListViewModel?

    public init(
        authRepository: any AuthRepository,
        vaultSession: any VaultSessionProtocol,
        navigator: any Navigating,
        noteRepository: any NoteRepository,
        credentialStore: any CredentialStore
    ) {
        self.authRepository = authRepository
        self.vaultSession = vaultSession
        self.navigator = navigator
        self.noteRepository = noteRepository
        self.credentialStore = credentialStore

        Task {
            for await isActive in vaultSession.changes where !isActive {
                noteListViewModel = nil
            }
        }
    }

    public func makeNoteListViewModel() -> DefaultNoteListViewModel {
        if let noteListViewModel {
            return noteListViewModel
        }

        let viewModel = DefaultNoteListViewModel(
            authRepository: authRepository,
            vaultSession: vaultSession,
            noteRepository: noteRepository,
            navigator: navigator,
            credentialStore: credentialStore
        )
        noteListViewModel = viewModel
        return viewModel
    }

    public func makeNoteDetailViewModel(noteID: UUID) -> DefaultNoteDetailViewModel {
        DefaultNoteDetailViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            vaultSession: vaultSession,
            navigator: navigator
        )
    }

    public func makeCreateNoteViewModel() -> DefaultCreateNoteViewModel {
        DefaultCreateNoteViewModel(
            noteRepository: noteRepository,
            vaultSession: vaultSession,
            navigator: navigator
        )
    }
}
