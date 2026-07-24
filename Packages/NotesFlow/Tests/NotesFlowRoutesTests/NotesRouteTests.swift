import NavigationProtocol
import XCTest

@testable import NotesFlowRoutes

final class NotesRouteTests: XCTestCase {
    func testNotesRouteConformsToRoute() {
        let route: any Route = NotesRoute.list
        XCTAssertTrue(route is NotesRoute)
    }

    func testNotesRouteIncludesList() {
        XCTAssertEqual(NotesRoute.list, .list)
    }

    func testNotesRouteIsSendable() {
        let route: any Route & Sendable = NotesRoute.list
        XCTAssertTrue(route is NotesRoute)
    }
}
