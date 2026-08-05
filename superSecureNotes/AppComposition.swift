import AuthFlowRoutes
import AuthFlowProtocol
import AuthFlowUI
import CredentialStore
import Navigation
import NoteRepository
import NotesFlow
import NotesFlowRoutes
import Observation
import ShareNote
import ShareNoteRoutes
import SwiftUI

@Observable
@MainActor
final class AppComposition {
    let appDependencies: AppDependencies
    let authDependencies: AuthFlowDependencies
    let notesDependencies: NotesFlowDependencies
    let shareNoteDependencies: ShareNoteDependencies
    let navigation: NavigationCoordinator
    let lockCoordinator: LockCoordinator

    private var lastSyncedHasLocalSetup: Bool?
    private var lastSyncedVaultActive: Bool?
    private var syncRetryObservationTask: Task<Void, Never>?

    init() {
        let dependencies = AppDependencies()
        self.appDependencies = dependencies
        navigation = NavigationCoordinator()
        authDependencies = AuthFlowDependencies(
            authRepository: dependencies.authRepository,
            vaultRepository: dependencies.vaultRepository,
            vaultAuthenticator: dependencies.vaultAuthenticator,
            vaultSession: dependencies.vaultSession,
            notesIndexStore: dependencies.notesIndexStore,
            navigator: navigation.navigator,
            credentialStore: dependencies.credentialStore,
            biometricAuthenticator: dependencies.biometricAuthenticator,
            networkReachability: dependencies.networkReachability,
            noteSync: dependencies.noteSyncService
        )
        notesDependencies = NotesFlowDependencies(
            authRepository: dependencies.authRepository,
            vaultSession: dependencies.vaultSession,
            navigator: navigation.navigator,
            noteRepository: dependencies.noteRepository,
            credentialStore: dependencies.credentialStore,
            noteSync: dependencies.noteSyncService,
            performLogout: {
                await LogoutReset.perform(
                    authRepository: dependencies.authRepository,
                    vaultSession: dependencies.vaultSession,
                    notesIndexStore: dependencies.notesIndexStore,
                    credentialStore: dependencies.credentialStore
                )
            }
        )
        shareNoteDependencies = ShareNoteDependencies(
            navigator: navigation.navigator
        )
        let navigator = navigation.navigator
        let credentialStore = dependencies.credentialStore
        lockCoordinator = LockCoordinator(
            vaultSession: dependencies.vaultSession,
            authRepository: dependencies.authRepository,
            notesIndexStore: dependencies.notesIndexStore
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
        startSyncRetryObservation()
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

    private func startSyncRetryObservation() {
        syncRetryObservationTask = NoteSyncRetryObserver.start(
            reachability: appDependencies.networkReachability,
            noteSync: appDependencies.noteSyncService
        )
    }
}
