import AuthFlowProtocol
import AuthFlowRoutes
import Navigation
import SwiftUI

extension RouteRegistry {
    public func registerAuthRoutes(
        deps: any AuthFlowDependencyProviding,
        navigator: any LoginNavigating
    ) {
        register(AuthRoute.self) { route in
            AnyView(
                AuthNavigation.view(
                    for: route,
                    deps: deps,
                    navigator: navigator
                )
            )
        }
    }
}
