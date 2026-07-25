import XCTest

@testable import Navigation

@MainActor
final class NavigationCoordinatorTests: XCTestCase {
    func testCoordinatorExposesNavigatorRegistryAndHostModel() {
        let coordinator = NavigationCoordinator()

        XCTAssertNotNil(coordinator.navigator)
        XCTAssertNotNil(coordinator.registry)
        XCTAssertIdentical(coordinator.hostModel.registry, coordinator.registry)
    }

    func testCoordinatorUsesProvidedRouterAndRegistry() {
        let router = NavigationRouter()
        let registry = RouteRegistry(assertOnUnregisteredRoutes: false)
        let coordinator = NavigationCoordinator(router: router, registry: registry)

        XCTAssertIdentical(coordinator.hostModel.router, router)
        XCTAssertIdentical(coordinator.registry, registry)
    }
}
