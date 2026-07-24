import AuthFlowRoutes
import NavigationProtocol
import NotesFlowRoutes

@MainActor
enum SessionRootNavigation {
    static func apply(isVaultActive: Bool, to router: any NavigationRouting) {
        if isVaultActive {
            router.setRoot(NotesRoute.list)
        } else {
            router.setRoot(AuthRoute.login)
        }
    }
}
