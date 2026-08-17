import NotesFlow
import XCTest

final class EmptyPlaceholderViewTests: XCTestCase {
    func testEmptyPlaceholderViewSourceUsesContentUnavailableViewWithParameters() throws {
        let source = try Self.emptyPlaceholderViewSource()

        XCTAssertTrue(source.contains("ContentUnavailableView"))
        XCTAssertTrue(source.contains("let systemImage: String"))
        XCTAssertTrue(source.contains("let title: String"))
        XCTAssertTrue(source.contains("let description: String"))
        XCTAssertTrue(source.contains("Image(systemName: systemImage)"))
        XCTAssertTrue(source.contains("Text(verbatim: title)"))
        XCTAssertTrue(source.contains("Text(verbatim: description)"))
    }

    func testEmptyPlaceholderViewSourceHasNoButton() throws {
        let source = try Self.emptyPlaceholderViewSource()

        XCTAssertFalse(source.contains("Button"))
    }

    private static func emptyPlaceholderViewSource() throws -> String {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = packageRoot
            .appendingPathComponent("Sources/NotesFlow/EmptyPlaceholderView.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
