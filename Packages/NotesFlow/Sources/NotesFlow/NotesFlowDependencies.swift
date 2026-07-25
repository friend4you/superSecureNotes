import AuthRepositoryProtocol
import NavigationProtocol
import NotesFlowRoutes
import VaultSessionProtocol

@MainActor
public final class NotesFlowDependencies: NotesDependencyProviding {
    private let authRepository: any AuthRepository
    private let vaultSession: any VaultSessionProtocol
    private let navigator: any Navigating

    public init(
        authRepository: any AuthRepository,
        vaultSession: any VaultSessionProtocol,
        navigator: any Navigating
    ) {
        self.authRepository = authRepository
        self.vaultSession = vaultSession
        self.navigator = navigator
    }

    public func makeNoteListViewModel() -> DefaultNoteListViewModel {
        DefaultNoteListViewModel(
            authRepository: authRepository,
            vaultSession: vaultSession
        )
    }
}
