import SwiftUI
import XCTest

@testable import Navigation

private enum TestRoute: Route {
    case root
    case detail(Int)
}

@MainActor
final class NavigationRouterTests: XCTestCase {
    func testSetRootReplacesNavigationPath() {
        let router = NavigationRouter()
        router.setRoot(TestRoute.root)
        router.push(TestRoute.detail(1))
        router.push(TestRoute.detail(2))

        router.setRoot(TestRoute.detail(99))

        var expected = NavigationPath()
        expected.append(TestRoute.detail(99))
        XCTAssertEqual(router.path, expected)
    }

    func testPushAppendsRouteToNavigationPath() {
        let router = NavigationRouter()
        router.setRoot(TestRoute.root)

        router.push(TestRoute.detail(42))

        var expected = NavigationPath()
        expected.append(TestRoute.root)
        expected.append(TestRoute.detail(42))
        XCTAssertEqual(router.path, expected)
    }

    func testPopToRootKeepsRootRoute() {
        let router = NavigationRouter()
        router.setRoot(TestRoute.root)
        router.push(TestRoute.detail(1))
        router.push(TestRoute.detail(2))

        router.popToRoot()

        var expected = NavigationPath()
        expected.append(TestRoute.root)
        XCTAssertEqual(router.path, expected)
    }

    func testPresentSetsModalState() {
        let router = NavigationRouter()

        router.present(TestRoute.detail(7), style: .sheet)

        XCTAssertEqual(router.presentedRoute?.base as? TestRoute, .detail(7))
        XCTAssertEqual(router.presentationStyle, .sheet)
    }

    func testPresentFullScreenCoverSetsModalState() {
        let router = NavigationRouter()

        router.present(TestRoute.root, style: .fullScreenCover)

        XCTAssertEqual(router.presentedRoute?.base as? TestRoute, .root)
        XCTAssertEqual(router.presentationStyle, .fullScreenCover)
    }

    func testSetRootClearsPresentedModal() {
        let router = NavigationRouter()
        router.present(TestRoute.detail(1), style: .fullScreenCover)

        router.setRoot(TestRoute.root)

        XCTAssertNil(router.presentedRoute)
        XCTAssertNil(router.presentationStyle)
    }
}
