import AuthFlowRoutes
import AuthFlowProtocol
import AuthFlowUI
import Navigation
import NotesFlow
import NotesFlowRoutes
import Observation

@Observable
@MainActor
final class AppComposition {
    let infrastructure: AppDependencies
    let authDependencies: AuthFlowDependencies
    let notesDependencies: NotesFlowDependencies
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
        notesDependencies = NotesFlowDependencies(navigator: navigation.navigator)
        navigation.registry.registerAuthRoutes(deps: authDependencies)
        navigation.registry.registerNotesRoutes(deps: notesDependencies)
        #if DEBUG
        navigation.registry.verifyRegistered([AuthRoute.self, NotesRoute.self])
        #endif
    }

    func syncRootRoute(isVaultActive: Bool) {
        SessionRootNavigation.apply(isVaultActive: isVaultActive, to: navigation.navigator)
    }
}
