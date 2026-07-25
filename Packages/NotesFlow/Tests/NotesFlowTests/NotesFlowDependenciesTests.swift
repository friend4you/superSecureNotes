import NavigationProtocol
import NotesFlow
import XCTest

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
final class NotesFlowDependenciesTests: XCTestCase {
    func testNotesFlowDependenciesConformsToNotesDependencyProviding() {
        let dependencies: any NotesDependencyProviding = NotesFlowDependencies(
            navigator: MockNavigating()
        )

        XCTAssertTrue(dependencies is NotesFlowDependencies)
    }
}
