import XCTest

@testable import NavigationProtocol

private enum SampleRoute: Route {
    case home
    case detail(Int)
}

final class RouteTests: XCTestCase {
    func testSampleRouteConformsToRoute() {
        let route: any Route = SampleRoute.home
        XCTAssertTrue(route is SampleRoute)
    }

    func testSampleRouteIsHashable() {
        XCTAssertEqual(SampleRoute.home, SampleRoute.home)
        XCTAssertEqual(SampleRoute.detail(1), SampleRoute.detail(1))
        XCTAssertNotEqual(SampleRoute.home, SampleRoute.detail(1))
    }

    func testSampleRouteIsSendable() {
        let route: any Route & Sendable = SampleRoute.home
        XCTAssertTrue(route is SampleRoute)
    }
}

final class RoutePresentationTests: XCTestCase {
    func testSheetPresentationCase() {
        XCTAssertEqual(RoutePresentation.sheet, .sheet)
    }

    func testFullScreenCoverPresentationCase() {
        XCTAssertEqual(RoutePresentation.fullScreenCover, .fullScreenCover)
    }
}
