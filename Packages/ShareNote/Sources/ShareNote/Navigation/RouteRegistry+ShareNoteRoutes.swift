import Navigation
import ShareNoteRoutes
import SwiftUI

extension RouteRegistry {
    public func registerShareNoteRoutes(deps: any ShareNoteDependencyProviding) {
        register(ShareNoteRoute.self) { route in
            AnyView(ShareNoteNavigation.view(for: route, deps: deps))
        }
    }
}
