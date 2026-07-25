import XCTest

@testable import NavigationProtocol

private enum NavigatingTestRoute: Route {
    case home
}

@MainActor
private final class MockNavigating: Navigating {
    private(set) var dismissPresentationCallCount = 0
    private(set) var pushedRoutes: [AnyHashable] = []

    func setRoot<R: Route>(_ route: R) {}

    func push<R: Route>(_ route: R) {
        pushedRoutes.append(AnyHashable(route))
    }

    func present<R: Route>(_ route: R, style: RoutePresentation) {}

    func pop() {}

    func popToRoot() {}

    func dismissPresentation() {
        dismissPresentationCallCount += 1
    }
}

final class NavigatingTests: XCTestCase {
    @MainActor
    func testNavigatingConformsToNavigationRouting() {
        let navigator: any NavigationRouting = MockNavigating()

        navigator.push(NavigatingTestRoute.home)

        XCTAssertEqual((navigator as? MockNavigating)?.pushedRoutes.count, 1)
    }

    @MainActor
    func testNavigatingIncludesDismissPresentation() {
        let navigator = MockNavigating()

        navigator.dismissPresentation()

        XCTAssertEqual(navigator.dismissPresentationCallCount, 1)
    }
}
