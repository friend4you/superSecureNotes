import NavigationProtocol
import SwiftUI

private struct NavigationRouterKey: EnvironmentKey {
    static let defaultValue: (any NavigationRouting)? = nil
}

extension EnvironmentValues {
    public var navigationRouter: (any NavigationRouting)? {
        get { self[NavigationRouterKey.self] }
        set { self[NavigationRouterKey.self] = newValue }
    }
}
