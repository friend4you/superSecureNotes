import AuthFlowRoutes
import NavigationProtocol
import NotesFlowRoutes

@MainActor
enum SessionRootNavigation {
    static func apply(isVaultActive: Bool, to navigator: any Navigating) {
        if isVaultActive {
            navigator.setRoot(NotesRoute.list)
        } else {
            navigator.setRoot(AuthRoute.login)
        }
    }
}
