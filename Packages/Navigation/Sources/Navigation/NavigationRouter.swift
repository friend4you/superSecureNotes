import NavigationProtocol
import Observation
import SwiftUI

@Observable
@MainActor
public final class NavigationRouter: NavigationRouting {
    public private(set) var path = NavigationPath()
    public private(set) var presentedRoute: AnyHashable?
    public private(set) var presentedRouteType: ObjectIdentifier?
    public private(set) var presentationStyle: RoutePresentation?

    private var rootRouteValue: AnyHashable?
    private var rootRouteType: ObjectIdentifier?

    public init() {}

    public var pathBinding: Binding<NavigationPath> {
        Binding(
            get: { self.path },
            set: { self.path = $0 }
        )
    }

    var rootRoute: (route: AnyHashable, typeID: ObjectIdentifier)? {
        guard let rootRouteValue, let rootRouteType else { return nil }
        return (rootRouteValue, rootRouteType)
    }

    public func setRoot<R: Route>(_ route: R) {
        rootRouteValue = AnyHashable(route)
        rootRouteType = ObjectIdentifier(R.self)
        path = NavigationPath()
        presentedRoute = nil
        presentedRouteType = nil
        presentationStyle = nil
    }

    public func push<R: Route>(_ route: R) {
        path.append(route)
    }

    public func present<R: Route>(_ route: R, style: RoutePresentation) {
        presentedRoute = AnyHashable(route)
        presentedRouteType = ObjectIdentifier(R.self)
        presentationStyle = style
    }

    public func dismissPresentation() {
        presentedRoute = nil
        presentedRouteType = nil
        presentationStyle = nil
    }

    public func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    public func popToRoot() {
        path = NavigationPath()
    }
}
