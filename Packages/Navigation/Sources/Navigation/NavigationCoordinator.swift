import Observation
import SwiftUI

@Observable
@MainActor
public final class NavigationCoordinator {
    public let router: NavigationRouter
    public let registry: RouteRegistry
    public let hostModel: NavigationHostModel

    public init(
        router: NavigationRouter? = nil,
        registry: RouteRegistry? = nil
    ) {
        self.router = router ?? NavigationRouter()
        self.registry = registry ?? RouteRegistry()
        self.hostModel = NavigationHostModel(router: self.router, registry: self.registry)
    }
}
