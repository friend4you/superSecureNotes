import NotesFlow
import XCTest

@testable import NotesFlow

final class NoteAttachmentsSectionTests: XCTestCase {
    func testNoteAttachmentsSectionSourceHidesWhenEmpty() throws {
        let source = try Self.noteAttachmentsSectionSource()

        XCTAssertTrue(source.contains("if !items.isEmpty"))
    }

    func testNoteAttachmentsSectionSourceRendersFilename() throws {
        let source = try Self.noteAttachmentsSectionSource()

        XCTAssertTrue(source.contains("Text(item.filename)"))
        XCTAssertTrue(source.contains("ForEach(items)"))
    }

    func testNoteAttachmentsSectionSourceTrashCallsRemoveCallback() throws {
        let source = try Self.noteAttachmentsSectionSource()

        XCTAssertTrue(source.contains("onRemove(item.id)"))
        XCTAssertTrue(source.contains("Image(systemName: \"trash\")"))
        XCTAssertTrue(source.contains("notes.attachments.remove"))
        XCTAssertFalse(source.contains("role: .destructive"))
    }

    func testNoteAttachmentsSectionSourceRequestsPreviewViaCallback() throws {
        let source = try Self.noteAttachmentsSectionSource()

        XCTAssertTrue(source.contains("openPreview(for: item)"))
        XCTAssertTrue(source.contains("onPreview(fileURL)"))
        XCTAssertTrue(source.contains("onPreviewUnavailable(item.filename)"))
        XCTAssertTrue(source.contains("AttachmentPreviewSupport.canPreview(fileURL: fileURL)"))
        XCTAssertTrue(source.contains("dataForPreview(item.id)"))
        XCTAssertTrue(source.contains("onTapGesture"))
        XCTAssertFalse(source.contains("fullScreenCover"))
    }

    private static func noteAttachmentsSectionSource() throws -> String {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = packageRoot
            .appendingPathComponent("Sources/NotesFlow/Attachments/NoteAttachmentsSection.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
