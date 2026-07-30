import NotesFlow
import XCTest

@testable import NotesFlow

final class AttachmentPreviewPresentationTests: XCTestCase {
    func testAttachmentPreviewPresentationModifierSourceUsesFullScreenCover() throws {
        let source = try Self.attachmentPreviewPresentationSource()

        XCTAssertTrue(source.contains("fullScreenCover(item:"))
        XCTAssertTrue(source.contains("AttachmentPreviewScreen"))
        XCTAssertTrue(source.contains("func attachmentPreview"))
    }

    private static func attachmentPreviewPresentationSource() throws -> String {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = packageRoot
            .appendingPathComponent("Sources/NotesFlow/Attachments/AttachmentPreviewPresentation.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
