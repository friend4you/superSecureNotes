import SwiftUI

public struct NavigationHost: View {
    @Bindable private var model: NavigationHostModel

    public init(model: NavigationHostModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack(path: model.pushPath) {
            model.registry.applyingNavigationDestinations(to: rootContent)
        }
        .sheet(isPresented: model.isSheetPresented) {
            presentedRouteContent
        }
        #if os(iOS)
        .fullScreenCover(isPresented: model.isFullScreenCoverPresented) {
            presentedRouteContent
        }
        #else
        .sheet(isPresented: model.isFullScreenCoverPresented) {
            presentedRouteContent
        }
        #endif
    }
    
    @ViewBuilder
    public var rootContent: some View {
        if let rootRoute = model.router.rootRoute {
            model.registry.view(forAny: rootRoute.route, routeType: rootRoute.typeID)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    public var presentedRouteContent: some View {
        if let route = model.router.presentedRoute, let routeType = model.router.presentedRouteType {
            model.registry.view(forAny: route, routeType: routeType)
        }
    }
}
