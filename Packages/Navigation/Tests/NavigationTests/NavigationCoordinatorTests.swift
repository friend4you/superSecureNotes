import XCTest

@testable import Navigation

@MainActor
final class NavigationCoordinatorTests: XCTestCase {
    func testCoordinatorExposesRouterRegistryAndHostModel() {
        let coordinator = NavigationCoordinator()

        XCTAssertNotNil(coordinator.router)
        XCTAssertNotNil(coordinator.registry)
        XCTAssertIdentical(coordinator.hostModel.router, coordinator.router)
        XCTAssertIdentical(coordinator.hostModel.registry, coordinator.registry)
    }

    func testCoordinatorUsesProvidedRouterAndRegistry() {
        let router = NavigationRouter()
        let registry = RouteRegistry(assertOnUnregisteredRoutes: false)
        let coordinator = NavigationCoordinator(router: router, registry: registry)

        XCTAssertIdentical(coordinator.router, router)
        XCTAssertIdentical(coordinator.registry, registry)
    }
}
