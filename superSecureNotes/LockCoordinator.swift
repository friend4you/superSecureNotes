import AuthFlowDomainProtocol
import AuthRepositoryProtocol
import NoteRepositoryProtocol
import SwiftUI
import VaultSessionProtocol

@MainActor
final class LockCoordinator {
    private let vaultSession: any VaultSessionProtocol
    private let authRepository: any AuthRepository
    private let notesIndexStore: any NotesIndexStoreProtocol
    private let sessionPasswordCache: any SessionPasswordCaching
    private let onLock: () -> Void
    private var protectedDataObservation: Task<Void, Never>?

    init(
        vaultSession: any VaultSessionProtocol,
        authRepository: any AuthRepository,
        notesIndexStore: any NotesIndexStoreProtocol,
        sessionPasswordCache: any SessionPasswordCaching,
        onLock: @escaping () -> Void
    ) {
        self.vaultSession = vaultSession
        self.authRepository = authRepository
        self.notesIndexStore = notesIndexStore
        self.sessionPasswordCache = sessionPasswordCache
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
            sessionPasswordCache.clear()
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
