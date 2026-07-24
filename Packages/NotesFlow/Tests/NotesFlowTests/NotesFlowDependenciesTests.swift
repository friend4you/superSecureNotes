import NotesFlow
import XCTest

@MainActor
final class NotesFlowDependenciesTests: XCTestCase {
    func testNotesFlowDependenciesConformsToNotesDependencyProviding() {
        let dependencies: any NotesDependencyProviding = NotesFlowDependencies()

        XCTAssertTrue(dependencies is NotesFlowDependencies)
    }
}
