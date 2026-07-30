import AuthFlowRoutes
import NavigationProtocol
import NotesFlowRoutes

@MainActor
enum SessionRootNavigation {
    static func apply(
        hasLocalSetup: Bool,
        isVaultActive: Bool,
        to navigator: any Navigating
    ) {
        if isVaultActive {
            navigator.setRoot(NotesRoute.list)
        } else if hasLocalSetup {
            navigator.setRoot(AuthRoute.unlock)
        } else {
            navigator.setRoot(AuthRoute.login)
        }
    }
}
