import Observation
import SwiftUI

@Observable
@MainActor
public final class NavigationCoordinator {
    public let navigator: AppNavigator
    public let registry: RouteRegistry
    public let hostModel: NavigationHostModel

    public init(
        router: NavigationRouter? = nil,
        registry: RouteRegistry? = nil
    ) {
        let router = router ?? NavigationRouter()
        let registry = registry ?? RouteRegistry()
        self.registry = registry
        self.navigator = AppNavigator(router: router, registry: registry)
        self.hostModel = NavigationHostModel(router: router, registry: registry)
    }
}
