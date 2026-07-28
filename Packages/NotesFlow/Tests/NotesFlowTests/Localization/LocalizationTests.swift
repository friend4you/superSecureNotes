import NotesFlow
import XCTest

@testable import NotesFlow

final class LocalizationTests: XCTestCase {
    func testStringCatalogIsBundledWithNotesFlow() {
        XCTAssertTrue(NotesFlowUIBundleTesting.hasLocalizedCatalog)
    }
}
