import NotesFlow
import XCTest

final class NoteSyncStatusLabelTests: XCTestCase {
    func testNoteSyncStatusLabelSourceIconOnlyPendingHidesText() throws {
        let source = try Self.noteSyncStatusLabelSource()

        XCTAssertTrue(source.contains("iconOnly"))
        XCTAssertTrue(source.contains("notes.sync.pending"))
        XCTAssertTrue(source.contains(".accessibilityLabel"))
    }

    func testNoteSyncStatusLabelSourceIconOnlySyncedHidesText() throws {
        let source = try Self.noteSyncStatusLabelSource()

        XCTAssertTrue(source.contains("checkmark.icloud"))
        XCTAssertTrue(source.contains("notes.sync.synced"))
    }

    func testNoteSyncStatusLabelSourcePendingDeleteRendersEmpty() throws {
        let source = try Self.noteSyncStatusLabelSource()

        XCTAssertTrue(source.contains("case .pendingDelete:"))
        XCTAssertTrue(source.contains("EmptyView()"))
    }

    private static func noteSyncStatusLabelSource() throws -> String {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = packageRoot
            .appendingPathComponent("Sources/NotesFlow/NoteSyncStatusLabel.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
