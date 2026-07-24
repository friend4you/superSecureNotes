import NotesFlow
import XCTest

@testable import superSecureNotes

@MainActor
final class AppCompositionTests: XCTestCase {
    func testAppUsesNotesFlowDependencies() {
        let notesDependencies = NotesFlowDependencies()

        XCTAssertTrue(notesDependencies is NotesDependencyProviding)
    }
}
