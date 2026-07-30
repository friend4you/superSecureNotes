import AuthRepositoryProtocol
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
    private var noteListViewModel: DefaultNoteListViewModel?

    public init(
        authRepository: any AuthRepository,
        vaultSession: any VaultSessionProtocol,
        navigator: any Navigating,
        noteRepository: any NoteRepository
    ) {
        self.authRepository = authRepository
        self.vaultSession = vaultSession
        self.navigator = navigator
        self.noteRepository = noteRepository

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
            navigator: navigator
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
