import Foundation
import NavigationProtocol
import XCTest

@testable import ShareNoteRoutes

final class ShareNoteRouteTests: XCTestCase {
    func testShareNoteRouteConformsToRoute() {
        let route: any Route = ShareNoteRoute.share(noteID: UUID())
        XCTAssertTrue(route is ShareNoteRoute)
    }

    func testShareNoteRouteIncludesShareWithNoteID() {
        let noteID = UUID()
        XCTAssertEqual(ShareNoteRoute.share(noteID: noteID), .share(noteID: noteID))
    }

    func testShareNoteRouteIsSendable() {
        let route: any Route & Sendable = ShareNoteRoute.share(noteID: UUID())
        XCTAssertTrue(route is ShareNoteRoute)
    }
}
