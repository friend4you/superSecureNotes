import AuthFlowProtocol
import AuthFlowUI
import Navigation
import NotesFlow
import Observation

@Observable
@MainActor
final class AppComposition {
    let infrastructure: AppDependencies
    let authDependencies: AuthFlowDependencies
    let notesDependencies: NotesFlowDependencies
    let navigation: NavigationCoordinator
    private let loginNavigator: AuthLoginNavigator

    init() {
        let infrastructure = AppDependencies()
        self.infrastructure = infrastructure
        authDependencies = AuthFlowDependencies(
            authRepository: infrastructure.authRepository,
            vaultRepository: infrastructure.vaultRepository,
            vaultAuthenticator: infrastructure.vaultAuthenticator,
            vaultSession: infrastructure.vaultSession
        )
        notesDependencies = NotesFlowDependencies()
        navigation = NavigationCoordinator()
        loginNavigator = AuthLoginNavigator(router: navigation.router)
        navigation.registry.registerAuthRoutes(
            deps: authDependencies,
            navigator: loginNavigator
        )
        navigation.registry.registerNotesRoutes(deps: notesDependencies)
    }

    func syncRootRoute(isVaultActive: Bool) {
        SessionRootNavigation.apply(isVaultActive: isVaultActive, to: navigation.router)
    }
}
