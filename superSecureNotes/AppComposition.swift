import AuthFlowRoutes
import AuthFlowProtocol
import AuthFlowUI
import CredentialStore
import Navigation
import NotesFlow
import NotesFlowRoutes
import Observation
import ShareNote
import ShareNoteRoutes
import SwiftUI

@Observable
@MainActor
final class AppComposition {
    let infrastructure: AppDependencies
    let authDependencies: AuthFlowDependencies
    let notesDependencies: NotesFlowDependencies
    let shareNoteDependencies: ShareNoteDependencies
    let navigation: NavigationCoordinator
    let lockCoordinator: LockCoordinator

    private var lastSyncedHasLocalSetup: Bool?
    private var lastSyncedVaultActive: Bool?

    init() {
        let infrastructure = AppDependencies()
        self.infrastructure = infrastructure
        navigation = NavigationCoordinator()
        authDependencies = AuthFlowDependencies(
            authRepository: infrastructure.authRepository,
            vaultRepository: infrastructure.vaultRepository,
            vaultAuthenticator: infrastructure.vaultAuthenticator,
            vaultSession: infrastructure.vaultSession,
            navigator: navigation.navigator,
            credentialStore: infrastructure.credentialStore,
            biometricAuthenticator: infrastructure.biometricAuthenticator,
            networkReachability: infrastructure.networkReachability
        )
        notesDependencies = NotesFlowDependencies(
            authRepository: infrastructure.authRepository,
            vaultSession: infrastructure.vaultSession,
            navigator: navigation.navigator,
            noteRepository: infrastructure.noteRepository,
            credentialStore: infrastructure.credentialStore
        )
        shareNoteDependencies = ShareNoteDependencies(
            navigator: navigation.navigator
        )
        let navigator = navigation.navigator
        let credentialStore = infrastructure.credentialStore
        lockCoordinator = LockCoordinator(
            vaultSession: infrastructure.vaultSession,
            authRepository: infrastructure.authRepository
        ) {
            SessionRootNavigation.apply(
                hasLocalSetup: credentialStore.hasLocalSetup,
                isVaultActive: false,
                to: navigator
            )
        }
        navigation.registry.registerAuthRoutes(deps: authDependencies)
        navigation.registry.registerNotesRoutes(deps: notesDependencies)
        navigation.registry.registerShareNoteRoutes(deps: shareNoteDependencies)
        #if DEBUG
        navigation.registry.verifyRegistered([AuthRoute.self, NotesRoute.self, ShareNoteRoute.self])
        #endif
    }

    func syncRootRoute(hasLocalSetup: Bool, isVaultActive: Bool) {
        guard lastSyncedHasLocalSetup != hasLocalSetup || lastSyncedVaultActive != isVaultActive else {
            return
        }
        lastSyncedHasLocalSetup = hasLocalSetup
        lastSyncedVaultActive = isVaultActive
        SessionRootNavigation.apply(
            hasLocalSetup: hasLocalSetup,
            isVaultActive: isVaultActive,
            to: navigation.navigator
        )
    }

    func handleScenePhase(_ phase: ScenePhase) {
        lockCoordinator.handleScenePhase(phase)
    }
}
