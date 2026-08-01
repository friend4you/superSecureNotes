import AuthRepositoryProtocol
import NoteRepositoryProtocol
import SwiftUI
import VaultSessionProtocol

@MainActor
final class LockCoordinator {
    private let vaultSession: any VaultSessionProtocol
    private let authRepository: any AuthRepository
    private let notesIndexStore: any NotesIndexStoreProtocol
    private let onLock: () -> Void
    private var protectedDataObservation: Task<Void, Never>?

    init(
        vaultSession: any VaultSessionProtocol,
        authRepository: any AuthRepository,
        notesIndexStore: any NotesIndexStoreProtocol,
        onLock: @escaping () -> Void
    ) {
        self.vaultSession = vaultSession
        self.authRepository = authRepository
        self.notesIndexStore = notesIndexStore
        self.onLock = onLock

        protectedDataObservation = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(
                named: .protectedDataWillBecomeUnavailable
            ) {
                self?.lock()
            }
        }
    }

    deinit {
        protectedDataObservation?.cancel()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        if phase == .background {
            lock()
        }
    }

    func lock() {
        Task {
            await notesIndexStore.close()
            await vaultSession.clear()
            await authRepository.clearSession()
            onLock()
        }
    }
}

private extension Notification.Name {
    static let protectedDataWillBecomeUnavailable = Notification.Name(
        "UIApplicationProtectedDataWillBecomeUnavailableNotification"
    )
}
