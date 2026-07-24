import SwiftUI

@Observable
@MainActor
public final class NavigationHostModel {
    public let router: NavigationRouter
    public let registry: RouteRegistry

    public init(router: NavigationRouter, registry: RouteRegistry) {
        self.router = router
        self.registry = registry
    }

    public var pushPath: Binding<NavigationPath> {
        router.pathBinding
    }

    public var isSheetPresented: Binding<Bool> {
        presentationBinding(for: .sheet)
    }

    public var isFullScreenCoverPresented: Binding<Bool> {
        presentationBinding(for: .fullScreenCover)
    }

    private func presentationBinding(for style: RoutePresentation) -> Binding<Bool> {
        Binding(
            get: { self.router.presentationStyle == style && self.router.presentedRoute != nil },
            set: { isPresented in
                if !isPresented {
                    self.router.dismissPresentation()
                }
            }
        )
    }
}
