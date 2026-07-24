import SwiftUI

private struct UnregisteredRoutePlaceholder: View {
    var body: some View {
        EmptyView()
    }
}

@MainActor
public final class RouteRegistry {
    private var builders: [ObjectIdentifier: (AnyHashable) -> AnyView] = [:]
    private var destinationModifiers: [(AnyView) -> AnyView] = []
    private let assertOnUnregisteredRoutes: Bool

    public init(assertOnUnregisteredRoutes: Bool = true) {
        self.assertOnUnregisteredRoutes = assertOnUnregisteredRoutes
    }

    public func register<R: Route>(
        _ routeType: R.Type,
        builder: @escaping (R) -> AnyView
    ) {
        builders[ObjectIdentifier(routeType)] = { hashable in
            guard let route = hashable.base as? R else {
                assertionFailure("Route type mismatch for \(routeType)")
                return Self.unregisteredPlaceholder
            }
            return builder(route)
        }
        destinationModifiers.append { view in
            AnyView(
                view.navigationDestination(for: routeType) { route in
                    builder(route)
                }
            )
        }
    }

    public func view<R: Route>(for route: R) -> AnyView {
        guard let builder = builders[ObjectIdentifier(R.self)] else {
            if assertOnUnregisteredRoutes {
                assertionFailure("No view registered for route type \(R.self)")
            }
            return Self.unregisteredPlaceholder
        }
        return builder(AnyHashable(route))
    }

    public func isRegistered<R: Route>(_ routeType: R.Type) -> Bool {
        builders[ObjectIdentifier(routeType)] != nil
    }

    public func view(forAny route: AnyHashable, routeType: ObjectIdentifier) -> AnyView {
        guard let builder = builders[routeType] else {
            if assertOnUnregisteredRoutes {
                assertionFailure("No view registered for route type id \(routeType)")
            }
            return Self.unregisteredPlaceholder
        }
        return builder(route)
    }

    func applyingNavigationDestinations<V: View>(to view: V) -> some View {
        destinationModifiers.reduce(AnyView(view)) { partial, modifier in
            modifier(partial)
        }
    }

    private static let unregisteredPlaceholder = AnyView(UnregisteredRoutePlaceholder())
}
