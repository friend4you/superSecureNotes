import NotesFlow
import XCTest

@testable import NotesFlow

final class AttachmentPreviewScreenTests: XCTestCase {
    func testAttachmentPreviewScreenSourceIncludesCloseButton() throws {
        let source = try Self.attachmentPreviewScreenSource()

        XCTAssertTrue(source.contains("common.close"))
        XCTAssertTrue(source.contains("ToolbarItem(placement: .cancellationAction)"))
        XCTAssertTrue(source.contains("dismiss()"))
        XCTAssertTrue(source.contains("QuickLookPreview"))
    }

    private static func attachmentPreviewScreenSource() throws -> String {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = packageRoot
            .appendingPathComponent("Sources/NotesFlow/Attachments/AttachmentPreviewScreen.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
