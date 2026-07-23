@MainActor
public protocol NavigationRouting: AnyObject {
    func push<R: Route>(_ route: R)
    func present<R: Route>(_ route: R, style: RoutePresentation)
    func pop()
    func popToRoot()
}
