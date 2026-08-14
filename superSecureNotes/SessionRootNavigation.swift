import AuthFlowRoutes
import NavigationProtocol
import NotesFlowRoutes

@MainActor
enum SessionRootNavigation {
    static func apply(
        hasLocalSetup: Bool,
        isVaultActive: Bool,
        pendingEnrollment: Bool,
        to navigator: any Navigating
    ) {
        if isVaultActive, !pendingEnrollment {
            navigator.setRoot(NotesRoute.list)
        } else if isVaultActive, pendingEnrollment {
            // Stay on current auth root while enrollment sheet is presented.
        } else if hasLocalSetup {
            navigator.setRoot(AuthRoute.unlock)
        } else {
            navigator.setRoot(AuthRoute.login)
        }
    }
}
