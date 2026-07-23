import XCTest

@testable import NavigationProtocol

private enum MockRoute: Route {
    case list
    case detail(Int)
}

@MainActor
private final class MockNavigationRouter: NavigationRouting {
    private(set) var pushedRoutes: [AnyHashable] = []
    private(set) var presentedRoutes: [(route: AnyHashable, style: RoutePresentation)] = []
    private(set) var popCount = 0
    private(set) var popToRootCount = 0

    func push<R: Route>(_ route: R) {
        pushedRoutes.append(AnyHashable(route))
    }

    func present<R: Route>(_ route: R, style: RoutePresentation) {
        presentedRoutes.append((AnyHashable(route), style))
    }

    func pop() {
        popCount += 1
    }

    func popToRoot() {
        popToRootCount += 1
    }
}

final class NavigationRoutingTests: XCTestCase {
    @MainActor
    func testPushRecordsRoute() {
        let router = MockNavigationRouter()

        router.push(MockRoute.list)

        XCTAssertEqual(router.pushedRoutes.count, 1)
        XCTAssertEqual(router.pushedRoutes.first?.base as? MockRoute, .list)
    }

    @MainActor
    func testPresentRecordsRouteAndStyle() {
        let router = MockNavigationRouter()

        router.present(MockRoute.detail(42), style: .sheet)

        XCTAssertEqual(router.presentedRoutes.count, 1)
        XCTAssertEqual(router.presentedRoutes.first?.style, .sheet)
        XCTAssertEqual(router.presentedRoutes.first?.route.base as? MockRoute, .detail(42))
    }

    @MainActor
    func testPresentFullScreenCoverRecordsStyle() {
        let router = MockNavigationRouter()

        router.present(MockRoute.list, style: .fullScreenCover)

        XCTAssertEqual(router.presentedRoutes.first?.style, .fullScreenCover)
    }

    @MainActor
    func testPopIncrementsCount() {
        let router = MockNavigationRouter()

        router.pop()

        XCTAssertEqual(router.popCount, 1)
    }

    @MainActor
    func testPopToRootIncrementsCount() {
        let router = MockNavigationRouter()

        router.popToRoot()

        XCTAssertEqual(router.popToRootCount, 1)
    }
}
