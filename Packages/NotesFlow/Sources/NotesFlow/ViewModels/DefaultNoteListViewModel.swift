import AuthRepositoryProtocol
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

    public init(
        authRepository: any AuthRepository,
        vaultSession: any VaultSessionProtocol
    ) {
        self.authRepository = authRepository
        self.vaultSession = vaultSession
    }

    public func logout() async {
        try? await authRepository.logout()
        await vaultSession.clear()
    }
}
