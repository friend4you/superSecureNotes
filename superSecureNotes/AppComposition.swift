import AuthFlowRoutes
import AuthFlowProtocol
import AuthFlowUI
import Navigation
import NotesFlow
import NotesFlowRoutes
import Observation
import ShareNote
import ShareNoteRoutes

@Observable
@MainActor
final class AppComposition {
    let infrastructure: AppDependencies
    let authDependencies: AuthFlowDependencies
    let notesDependencies: NotesFlowDependencies
    let shareNoteDependencies: ShareNoteDependencies
    let navigation: NavigationCoordinator

    init() {
        let infrastructure = AppDependencies()
        self.infrastructure = infrastructure
        navigation = NavigationCoordinator()
        authDependencies = AuthFlowDependencies(
            authRepository: infrastructure.authRepository,
            vaultRepository: infrastructure.vaultRepository,
            vaultAuthenticator: infrastructure.vaultAuthenticator,
            vaultSession: infrastructure.vaultSession,
            navigator: navigation.navigator
        )
        notesDependencies = NotesFlowDependencies(
            authRepository: infrastructure.authRepository,
            vaultSession: infrastructure.vaultSession,
            navigator: navigation.navigator
        )
        shareNoteDependencies = ShareNoteDependencies(
            navigator: navigation.navigator
        )
        navigation.registry.registerAuthRoutes(deps: authDependencies)
        navigation.registry.registerNotesRoutes(deps: notesDependencies)
        navigation.registry.registerShareNoteRoutes(deps: shareNoteDependencies)
        #if DEBUG
        navigation.registry.verifyRegistered([AuthRoute.self, NotesRoute.self, ShareNoteRoute.self])
        #endif
    }

    func syncRootRoute(isVaultActive: Bool) {
        SessionRootNavigation.apply(isVaultActive: isVaultActive, to: navigation.navigator)
    }
}
