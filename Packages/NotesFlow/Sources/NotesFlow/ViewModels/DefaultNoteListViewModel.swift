import AuthRepositoryProtocol
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
    func openDetail(noteID: UUID)
    func createNote()
    func share(noteID: UUID)
    func deleteNote(noteID: UUID) async
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

    public init(
        authRepository: any AuthRepository,
        vaultSession: any VaultSessionProtocol,
        noteRepository: any NoteRepository,
        navigator: any Navigating
    ) {
        self.authRepository = authRepository
        self.vaultSession = vaultSession
        self.noteRepository = noteRepository
        self.navigator = navigator
    }

    public func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            let loadedNotes = try await noteRepository.listNotes()
            notes = loadedNotes.sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
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

    public func logout() async {
        try? await authRepository.logout()
        await vaultSession.clear()
    }
}
