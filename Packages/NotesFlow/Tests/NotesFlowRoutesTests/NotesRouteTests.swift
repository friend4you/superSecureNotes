import Foundation
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

    func testNotesRouteIncludesDetailWithNoteID() {
        let noteID = UUID()
        XCTAssertEqual(NotesRoute.detail(noteID: noteID), .detail(noteID: noteID))
    }

    func testNotesRouteIncludesSharedDetailWithNoteID() {
        let noteID = UUID()
        XCTAssertEqual(NotesRoute.sharedDetail(noteID: noteID), .sharedDetail(noteID: noteID))
    }

    func testNotesRouteIncludesCreate() {
        XCTAssertEqual(NotesRoute.create, .create)
    }

    func testNotesRouteIsHashable() {
        let noteID = UUID()
        XCTAssertEqual(NotesRoute.list, .list)
        XCTAssertEqual(NotesRoute.detail(noteID: noteID), .detail(noteID: noteID))
        XCTAssertEqual(NotesRoute.sharedDetail(noteID: noteID), .sharedDetail(noteID: noteID))
        XCTAssertEqual(NotesRoute.create, .create)
        XCTAssertNotEqual(NotesRoute.list, .detail(noteID: noteID))
        XCTAssertNotEqual(NotesRoute.list, .create)
        XCTAssertNotEqual(NotesRoute.create, .detail(noteID: noteID))
        XCTAssertNotEqual(NotesRoute.detail(noteID: noteID), .sharedDetail(noteID: noteID))
    }

    func testNotesRouteIsSendable() {
        let route: any Route & Sendable = NotesRoute.list
        XCTAssertTrue(route is NotesRoute)

        let detailRoute: any Route & Sendable = NotesRoute.detail(noteID: UUID())
        XCTAssertTrue(detailRoute is NotesRoute)

        let sharedDetailRoute: any Route & Sendable = NotesRoute.sharedDetail(noteID: UUID())
        XCTAssertTrue(sharedDetailRoute is NotesRoute)

        let createRoute: any Route & Sendable = NotesRoute.create
        XCTAssertTrue(createRoute is NotesRoute)
    }
}
