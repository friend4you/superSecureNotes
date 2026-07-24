import NavigationProtocol
import Observation
import SwiftUI

@Observable
@MainActor
public final class NavigationRouter: NavigationRouting {
    public private(set) var path = NavigationPath()
    public private(set) var presentedRoute: AnyHashable?
    public private(set) var presentationStyle: RoutePresentation?

    public init() {}

    public func setRoot<R: Route>(_ route: R) {
        path = NavigationPath()
        path.append(route)
        presentedRoute = nil
        presentationStyle = nil
    }

    public func push<R: Route>(_ route: R) {
        path.append(route)
    }

    public func present<R: Route>(_ route: R, style: RoutePresentation) {
        presentedRoute = AnyHashable(route)
        presentationStyle = style
    }

    public func pop() {
        guard path.count > 1 else { return }
        path.removeLast()
    }

    public func popToRoot() {
        while path.count > 1 {
            path.removeLast()
        }
    }
}
