import NavigationProtocol

@MainActor
public final class AppNavigator: Navigating {
    private let router: NavigationRouter
    private let registry: RouteRegistry

    init(router: NavigationRouter, registry: RouteRegistry) {
        self.router = router
        self.registry = registry
    }

    public func setRoot<R: Route>(_ route: R) {
        guard isRegistered(R.self) else { return }
        router.setRoot(route)
    }

    public func push<R: Route>(_ route: R) {
        guard isRegistered(R.self) else { return }
        router.push(route)
    }

    public func present<R: Route>(_ route: R, style: RoutePresentation) {
        guard isRegistered(R.self) else { return }
        router.present(route, style: style)
    }

    public func pop() {
        router.pop()
    }

    public func popToRoot() {
        router.popToRoot()
    }

    public func dismissPresentation() {
        router.dismissPresentation()
    }

    private func isRegistered<R: Route>(_ type: R.Type) -> Bool {
        guard registry.isRegistered(type) else {
            if registry.shouldAssertOnUnregisteredRoutes {
                assertionFailure("Route type \(type) not registered — check AppComposition")
            }
            return false
        }
        return true
    }
}
