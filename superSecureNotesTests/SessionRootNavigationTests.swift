import AuthFlowRoutes
import NavigationProtocol
import NotesFlowRoutes
import XCTest

@testable import superSecureNotes

@MainActor
private final class MockNavigating: Navigating {
    private(set) var setRootRoutes: [AnyHashable] = []

    func setRoot<R: Route>(_ route: R) {
        setRootRoutes.append(AnyHashable(route))
    }

    func push<R: Route>(_ route: R) {}

    func present<R: Route>(_ route: R, style: RoutePresentation) {}

    func pop() {}

    func popToRoot() {}

    func dismissPresentation() {}
}

@MainActor
final class SessionRootNavigationTests: XCTestCase {
    func testInactiveSessionSetsAuthLoginRoot() {
        let navigator = MockNavigating()

        SessionRootNavigation.apply(isVaultActive: false, to: navigator)

        XCTAssertEqual(navigator.setRootRoutes.count, 1)
        XCTAssertEqual(navigator.setRootRoutes.first?.base as? AuthRoute, .login)
    }

    func testActiveSessionSetsNotesListRoot() {
        let navigator = MockNavigating()

        SessionRootNavigation.apply(isVaultActive: true, to: navigator)

        XCTAssertEqual(navigator.setRootRoutes.count, 1)
        XCTAssertEqual(navigator.setRootRoutes.first?.base as? NotesRoute, .list)
    }
}
