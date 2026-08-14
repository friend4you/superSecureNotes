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
    let sessionPasswordCache: SessionPasswordCache
    let pendingBiometricEnrollmentStore: UserDefaultsPendingBiometricEnrollmentStore

    private var lastSyncedHasLocalSetup: Bool?
    private var lastSyncedVaultActive: Bool?
    private var lastSyncedPendingEnrollment: Bool?
    private var syncRetryObservationTask: Task<Void, Never>?

    init() {
        let dependencies = AppDependencies()
        let navigation = NavigationCoordinator()
        let sessionPasswordCache = SessionPasswordCache()
        let pendingBiometricEnrollmentStore = UserDefaultsPendingBiometricEnrollmentStore()
        let credentialStore = dependencies.credentialStore
        InstallMarker.reconcileOrphanedCredentialsIfNeeded(
            credentialStore: credentialStore,
            pendingBiometricEnrollmentStore: pendingBiometricEnrollmentStore
        )
        let localAppDataWiper = FileSystemLocalAppDataWiper()
        let navigator = navigation.navigator

        let performLogout: () async -> Void = {
            await LogoutReset.perform(
                authRepository: dependencies.authRepository,
                vaultSession: dependencies.vaultSession,
                notesIndexStore: dependencies.notesIndexStore,
                credentialStore: credentialStore,
                sessionPasswordCache: sessionPasswordCache,
                pendingBiometricEnrollmentStore: pendingBiometricEnrollmentStore,
                localAppDataWiper: localAppDataWiper
            )
        }

        let notesDependencies = NotesFlowDependencies(
            authRepository: dependencies.authRepository,
            vaultSession: dependencies.vaultSession,
            navigator: navigator,
            noteRepository: dependencies.noteRepository,
            credentialStore: credentialStore,
            noteSync: dependencies.noteSyncService,
            performLogout: performLogout
        )

        let shareNoteDependencies = ShareNoteDependencies(
            navigator: navigator,
            noteRepository: dependencies.networkNoteRepository,
            vaultRepository: dependencies.networkVaultRepository,
            vaultSession: dependencies.vaultSession
        )

        let applyRootRoute: (Bool, Bool) -> Void = { hasLocalSetup, isVaultActive in
            SessionRootNavigation.apply(
                hasLocalSetup: hasLocalSetup,
                isVaultActive: isVaultActive,
                pendingEnrollment: pendingBiometricEnrollmentStore.isPending,
                to: navigator
            )
        }

        let authDependencies = AuthFlowDependencies(
            authRepository: dependencies.authRepository,
            vaultRepository: dependencies.vaultRepository,
            vaultAuthenticator: dependencies.vaultAuthenticator,
            vaultSession: dependencies.vaultSession,
            notesIndexStore: dependencies.notesIndexStore,
            navigator: navigator,
            credentialStore: credentialStore,
            biometricAuthenticator: dependencies.biometricAuthenticator,
            networkReachability: dependencies.networkReachability,
            noteSync: dependencies.noteSyncService,
            sessionPasswordCache: sessionPasswordCache,
            pendingBiometricEnrollmentStore: pendingBiometricEnrollmentStore,
            sessionExpiredNotifier: dependencies.sessionExpiredNotifier,
            syncRootRoute: {
                applyRootRoute(credentialStore.hasLocalSetup, true)
            },
            performLogout: performLogout
        )

        let lockCoordinator = LockCoordinator(
            vaultSession: dependencies.vaultSession,
            authRepository: dependencies.authRepository,
            notesIndexStore: dependencies.notesIndexStore,
            sessionPasswordCache: sessionPasswordCache
        ) {
            applyRootRoute(credentialStore.hasLocalSetup, false)
        }

        self.appDependencies = dependencies
        self.navigation = navigation
        self.sessionPasswordCache = sessionPasswordCache
        self.pendingBiometricEnrollmentStore = pendingBiometricEnrollmentStore
        self.notesDependencies = notesDependencies
        self.shareNoteDependencies = shareNoteDependencies
        self.authDependencies = authDependencies
        self.lockCoordinator = lockCoordinator

        navigation.registry.registerAuthRoutes(deps: authDependencies)
        navigation.registry.registerNotesRoutes(deps: notesDependencies)
        navigation.registry.registerShareNoteRoutes(deps: shareNoteDependencies)
        #if DEBUG
        navigation.registry.verifyRegistered([AuthRoute.self, NotesRoute.self, ShareNoteRoute.self])
        #endif
        startSyncRetryObservation()
    }

    func syncRootRoute(hasLocalSetup: Bool, isVaultActive: Bool) {
        let pendingEnrollment = pendingBiometricEnrollmentStore.isPending
        guard lastSyncedHasLocalSetup != hasLocalSetup
            || lastSyncedVaultActive != isVaultActive
            || lastSyncedPendingEnrollment != pendingEnrollment else {
            return
        }
        lastSyncedHasLocalSetup = hasLocalSetup
        lastSyncedVaultActive = isVaultActive
        lastSyncedPendingEnrollment = pendingEnrollment
        SessionRootNavigation.apply(
            hasLocalSetup: hasLocalSetup,
            isVaultActive: isVaultActive,
            pendingEnrollment: pendingEnrollment,
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
