import SwiftUI
import XCTest

@testable import Navigation

private enum RegisteredRoute: Route {
    case list
}

private enum UnregisteredRoute: Route {
    case other
}

@MainActor
final class AppNavigatorTests: XCTestCase {
    func testPushValidatesRegistrationBeforeDelegating() {
        let router = NavigationRouter()
        let registry = RouteRegistry(assertOnUnregisteredRoutes: false)
        registry.register(RegisteredRoute.self) { _ in
            AnyView(Text("Registered"))
        }
        let navigator = AppNavigator(router: router, registry: registry)
        router.setRoot(RegisteredRoute.list)

        navigator.push(UnregisteredRoute.other)

        XCTAssertTrue(router.path.isEmpty)
    }

    func testPushDelegatesToRouterWhenRegistered() {
        let router = NavigationRouter()
        let registry = RouteRegistry(assertOnUnregisteredRoutes: false)
        registry.register(RegisteredRoute.self) { _ in
            AnyView(Text("Registered"))
        }
        let navigator = AppNavigator(router: router, registry: registry)
        router.setRoot(RegisteredRoute.list)

        navigator.push(RegisteredRoute.list)

        var expected = NavigationPath()
        expected.append(RegisteredRoute.list)
        XCTAssertEqual(router.path, expected)
    }

    func testSetRootDelegatesToRouterWhenRegistered() {
        let router = NavigationRouter()
        let registry = RouteRegistry(assertOnUnregisteredRoutes: false)
        registry.register(RegisteredRoute.self) { _ in
            AnyView(Text("Registered"))
        }
        let navigator = AppNavigator(router: router, registry: registry)

        navigator.setRoot(RegisteredRoute.list)

        XCTAssertEqual(router.rootRoute?.route.base as? RegisteredRoute, .list)
    }

    func testPresentDelegatesToRouterWhenRegistered() {
        let router = NavigationRouter()
        let registry = RouteRegistry(assertOnUnregisteredRoutes: false)
        registry.register(RegisteredRoute.self) { _ in
            AnyView(Text("Registered"))
        }
        let navigator = AppNavigator(router: router, registry: registry)

        navigator.present(RegisteredRoute.list, style: .sheet)

        XCTAssertEqual(router.presentedRoute?.base as? RegisteredRoute, .list)
        XCTAssertEqual(router.presentationStyle, .sheet)
    }

    func testPopDelegatesToRouter() {
        let router = NavigationRouter()
        let registry = RouteRegistry(assertOnUnregisteredRoutes: false)
        registry.register(RegisteredRoute.self) { _ in
            AnyView(Text("Registered"))
        }
        let navigator = AppNavigator(router: router, registry: registry)
        router.setRoot(RegisteredRoute.list)
        router.push(RegisteredRoute.list)

        navigator.pop()

        XCTAssertTrue(router.path.isEmpty)
    }

    func testPopToRootDelegatesToRouter() {
        let router = NavigationRouter()
        let registry = RouteRegistry(assertOnUnregisteredRoutes: false)
        registry.register(RegisteredRoute.self) { _ in
            AnyView(Text("Registered"))
        }
        let navigator = AppNavigator(router: router, registry: registry)
        router.setRoot(RegisteredRoute.list)
        router.push(RegisteredRoute.list)

        navigator.popToRoot()

        XCTAssertTrue(router.path.isEmpty)
        XCTAssertEqual(router.rootRoute?.route.base as? RegisteredRoute, .list)
    }

    func testDismissPresentationDelegatesToRouter() {
        let router = NavigationRouter()
        let registry = RouteRegistry(assertOnUnregisteredRoutes: false)
        let navigator = AppNavigator(router: router, registry: registry)
        router.present(RegisteredRoute.list, style: .sheet)

        navigator.dismissPresentation()

        XCTAssertNil(router.presentedRoute)
        XCTAssertNil(router.presentationStyle)
    }
}
