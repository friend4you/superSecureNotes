import AuthFlowProtocol
import AuthFlowRoutes
import NavigationProtocol

public final class AuthLoginNavigator: LoginNavigating {
    private let router: any NavigationRouting

    public init(router: any NavigationRouting) {
        self.router = router
    }

    public func showRegister() {
        router.push(AuthRoute.register)
    }
}
