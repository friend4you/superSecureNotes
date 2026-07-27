import AuthRepositoryProtocol
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
    }

    public func makeNoteListViewModel() -> DefaultNoteListViewModel {
        DefaultNoteListViewModel(
            authRepository: authRepository,
            vaultSession: vaultSession,
            navigator: navigator
        )
    }
}
