import AuthRepositoryProtocol
import AuthFlowRoutes
import ShareNoteRoutes
import NavigationProtocol
import Foundation
import Observation
import VaultSessionProtocol

@MainActor
public protocol NoteListViewModel: Observable {
    func logout() async
}

@MainActor
@Observable
public final class DefaultNoteListViewModel: NoteListViewModel {
    private let authRepository: any AuthRepository
    private let vaultSession: any VaultSessionProtocol
    private let navigator: Navigating

    public init(
        authRepository: any AuthRepository,
        vaultSession: any VaultSessionProtocol,
        navigator: Navigating
    ) {
        self.authRepository = authRepository
        self.vaultSession = vaultSession
        self.navigator = navigator
    }

    public func logout() async {
        try? await authRepository.logout()
        await vaultSession.clear()
    }
    
    public func share() {
        navigator.present(ShareNoteRoute.share(noteID: UUID()), style: .sheet)
    }
}
