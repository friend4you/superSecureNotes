import AuthFlowRoutes
import AuthRepositoryProtocol
import CredentialStoreProtocol
import Foundation
import NavigationProtocol
import NoteRepositoryProtocol
import NotesFlowRoutes
import Observation
import ShareNoteRoutes
import VaultSessionProtocol

@MainActor
public protocol NoteListViewModel: Observable {
    var notes: [NoteSummary] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    func refresh() async
    func reloadSummaries() async
    func openDetail(noteID: UUID)
    func createNote()
    func share(noteID: UUID)
    func deleteNote(noteID: UUID) async
    func openSettings()
    func logout() async
}

@MainActor
@Observable
public final class DefaultNoteListViewModel: NoteListViewModel {
    public private(set) var notes: [NoteSummary] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    private let authRepository: any AuthRepository
    private let vaultSession: any VaultSessionProtocol
    private let noteRepository: any NoteRepository
    private let navigator: any Navigating
    private let credentialStore: any CredentialStore
    private let performLogout: () async -> Void
    private let noteSync: any NoteSyncing
    private nonisolated(unsafe) var syncOutcomeObservation: Task<Void, Never>?

    public init(
        authRepository: any AuthRepository,
        vaultSession: any VaultSessionProtocol,
        noteRepository: any NoteRepository,
        navigator: any Navigating,
        credentialStore: any CredentialStore,
        performLogout: @escaping () async -> Void,
        noteSync: any NoteSyncing = NoOpNoteSyncService()
    ) {
        self.authRepository = authRepository
        self.vaultSession = vaultSession
        self.noteRepository = noteRepository
        self.navigator = navigator
        self.credentialStore = credentialStore
        self.performLogout = performLogout
        self.noteSync = noteSync
        syncOutcomeObservation = Task { [weak self] in
            guard let self else { return }
            for await outcome in noteSync.syncOutcomes {
                await self.handleSyncOutcome(outcome)
            }
        }
    }

    deinit {
        syncOutcomeObservation?.cancel()
    }

    public func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        await noteSync.flushPending()

        await reloadSummaries()
    }

    public func reloadSummaries() async {
        do {
            let loadedNotes = try await noteRepository.listNotes()
            notes = loadedNotes.sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleSyncOutcome(_ outcome: NoteSyncOutcome) async {
        guard case .uploaded = outcome else {
            return
        }
        await reloadSummaries()
    }

    public func openDetail(noteID: UUID) {
        navigator.push(NotesRoute.detail(noteID: noteID))
    }

    public func createNote() {
        navigator.push(NotesRoute.create)
    }

    public func share(noteID: UUID) {
        navigator.present(ShareNoteRoute.share(noteID: noteID), style: .sheet)
    }

    public func deleteNote(noteID: UUID) async {
        do {
            try await noteRepository.deleteNote(noteID: noteID)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func openSettings() {
        navigator.push(AuthRoute.settings)
    }

    public func logout() async {
        await performLogout()
    }
}
