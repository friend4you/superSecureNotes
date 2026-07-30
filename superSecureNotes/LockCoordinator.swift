import AuthRepositoryProtocol
import SwiftUI
import VaultSessionProtocol

#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class LockCoordinator {
    private let vaultSession: any VaultSessionProtocol
    private let authRepository: any AuthRepository
    private let onLock: () -> Void

    #if canImport(UIKit)
    private var protectedDataObserver: NSObjectProtocol?
    #endif

    init(
        vaultSession: any VaultSessionProtocol,
        authRepository: any AuthRepository,
        onLock: @escaping () -> Void
    ) {
        self.vaultSession = vaultSession
        self.authRepository = authRepository
        self.onLock = onLock

        #if canImport(UIKit)
        protectedDataObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.lock()
            }
        }
        #endif
    }

    deinit {
        #if canImport(UIKit)
        if let protectedDataObserver {
            NotificationCenter.default.removeObserver(protectedDataObserver)
        }
        #endif
    }

    func handleScenePhase(_ phase: ScenePhase) {
        if phase == .background {
            lock()
        }
    }

    func lock() {
        Task {
            await vaultSession.clear()
            await authRepository.clearSession()
            onLock()
        }
    }
}
