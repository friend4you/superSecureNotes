import NotesFlow
import NoteRepositoryProtocol
import XCTest

@testable import NotesFlow

final class NoteAttachmentsSectionProgressTests: XCTestCase {
    func testNoteAttachmentsSectionSourceShowsPerRowProgress() throws {
        let source = try Self.noteAttachmentsSectionSource()

        XCTAssertTrue(source.contains("progressByID"))
        XCTAssertTrue(source.contains("ProgressView(value:"))
        XCTAssertTrue(source.contains("progress.fractionCompleted"))
    }

    func testNoteAttachmentsSectionSourceShowsRetryForFailedRows() throws {
        let source = try Self.noteAttachmentsSectionSource()

        XCTAssertTrue(source.contains("onRetry"))
        XCTAssertTrue(source.contains(".failed"))
        XCTAssertTrue(source.contains("notes.attachments.retry"))
    }

    func testNoteDetailViewSourcePassesProgressAndRetry() throws {
        let source = try Self.noteDetailViewSource()

        XCTAssertTrue(source.contains("progressByID: viewModel.attachmentProgressByID"))
        XCTAssertTrue(source.contains("onRetry:"))
        XCTAssertTrue(source.contains("retryAttachment"))
    }

    func testSharedNoteDetailViewSourcePassesProgressAndRetry() throws {
        let source = try Self.sharedNoteDetailViewSource()

        XCTAssertTrue(source.contains("progressByID: viewModel.attachmentProgressByID"))
        XCTAssertTrue(source.contains("onRetry:"))
        XCTAssertTrue(source.contains("retryAttachment"))
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

    private static func noteDetailViewSource() throws -> String {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = packageRoot
            .appendingPathComponent("Sources/NotesFlow/NoteDetailView.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }

    private static func sharedNoteDetailViewSource() throws -> String {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = packageRoot
            .appendingPathComponent("Sources/NotesFlow/SharedNoteDetailView.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
