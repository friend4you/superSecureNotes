import NotesFlowRoutes
import XCTest

@testable import NotesFlow

@MainActor
private final class MockNotesDependencies: NotesDependencyProviding {}

@MainActor
final class NotesNavigationTests: XCTestCase {
    func testViewForListBuildsNoteListView() {
        let deps = MockNotesDependencies()

        _ = NotesNavigation.listView(deps: deps)
    }

    func testViewForListUsesDependencyProviding() {
        let deps = MockNotesDependencies()

        _ = NotesNavigation.view(for: .list, deps: deps)
    }
}
