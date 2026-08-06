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
    private let performLogout: () async -> Void
    internal let noteSync: any NoteSyncing
    private var noteListViewModel: DefaultNoteListViewModel?
    private var noteDetailViewModels: [UUID: DefaultNoteDetailViewModel] = [:]
    private var sharedNoteDetailViewModels: [UUID: DefaultSharedNoteDetailViewModel] = [:]

    public init(
        authRepository: any AuthRepository,
        vaultSession: any VaultSessionProtocol,
        navigator: any Navigating,
        noteRepository: any NoteRepository,
        credentialStore: any CredentialStore,
        noteSync: any NoteSyncing = NoOpNoteSyncService(),
        performLogout: @escaping () async -> Void
    ) {
        self.authRepository = authRepository
        self.vaultSession = vaultSession
        self.navigator = navigator
        self.noteRepository = noteRepository
        self.credentialStore = credentialStore
        self.noteSync = noteSync
        self.performLogout = performLogout

        Task {
            for await isActive in vaultSession.changes where !isActive {
                noteListViewModel = nil
                noteDetailViewModels = [:]
                sharedNoteDetailViewModels = [:]
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
            credentialStore: credentialStore,
            performLogout: performLogout,
            noteSync: noteSync
        )
        noteListViewModel = viewModel
        return viewModel
    }

    public func makeNoteDetailViewModel(noteID: UUID) -> DefaultNoteDetailViewModel {
        if let existingViewModel = noteDetailViewModels[noteID] {
            return existingViewModel
        }

        let viewModel = DefaultNoteDetailViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            vaultSession: vaultSession,
            navigator: navigator,
            noteSync: noteSync
        )
        noteDetailViewModels[noteID] = viewModel
        return viewModel
    }

    public func makeSharedNoteDetailViewModel(noteID: UUID) -> DefaultSharedNoteDetailViewModel {
        if let existingViewModel = sharedNoteDetailViewModels[noteID] {
            return existingViewModel
        }

        let viewModel = DefaultSharedNoteDetailViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            vaultSession: vaultSession
        )
        sharedNoteDetailViewModels[noteID] = viewModel
        return viewModel
    }

    public func makeCreateNoteViewModel() -> DefaultCreateNoteViewModel {
        DefaultCreateNoteViewModel(
            noteRepository: noteRepository,
            vaultSession: vaultSession,
            navigator: navigator,
            noteSync: noteSync
        )
    }
}
