import NavigationProtocol
import NotesFlow
import XCTest

@testable import superSecureNotes

@MainActor
private final class MockNavigating: Navigating {
    func setRoot<R: Route>(_ route: R) {}
    func push<R: Route>(_ route: R) {}
    func present<R: Route>(_ route: R, style: RoutePresentation) {}
    func pop() {}
    func popToRoot() {}
    func dismissPresentation() {}
}

@MainActor
final class AppCompositionTests: XCTestCase {
    func testAppUsesNotesFlowDependencies() {
        let notesDependencies = NotesFlowDependencies(navigator: MockNavigating())

        XCTAssertTrue(notesDependencies is NotesDependencyProviding)
    }
}
