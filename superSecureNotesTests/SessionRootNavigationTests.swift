import AuthFlowRoutes
import NavigationProtocol
import NotesFlowRoutes
import XCTest

@testable import superSecureNotes

@MainActor
private final class MockNavigationRouter: NavigationRouting {
    private(set) var setRootRoutes: [AnyHashable] = []

    func setRoot<R: Route>(_ route: R) {
        setRootRoutes.append(AnyHashable(route))
    }

    func push<R: Route>(_ route: R) {}

    func present<R: Route>(_ route: R, style: RoutePresentation) {}

    func pop() {}

    func popToRoot() {}
}

@MainActor
final class SessionRootNavigationTests: XCTestCase {
    func testInactiveSessionSetsAuthLoginRoot() {
        let router = MockNavigationRouter()

        SessionRootNavigation.apply(isVaultActive: false, to: router)

        XCTAssertEqual(router.setRootRoutes.count, 1)
        XCTAssertEqual(router.setRootRoutes.first?.base as? AuthRoute, .login)
    }

    func testActiveSessionSetsNotesListRoot() {
        let router = MockNavigationRouter()

        SessionRootNavigation.apply(isVaultActive: true, to: router)

        XCTAssertEqual(router.setRootRoutes.count, 1)
        XCTAssertEqual(router.setRootRoutes.first?.base as? NotesRoute, .list)
    }
}
