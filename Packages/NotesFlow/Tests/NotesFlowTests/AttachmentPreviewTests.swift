import NotesFlow
import XCTest

@testable import NotesFlow

final class AttachmentPreviewTests: XCTestCase {
    func testWritePreviewFileCreatesReadableFile() throws {
        let store = AttachmentPreviewStore()
        let data = Data("preview".utf8)
        let fileURL = try store.writePreviewFile(data: data, filename: "sample.txt")

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertEqual(try Data(contentsOf: fileURL), data)
    }

    func testDeletePreviewFileRemovesDirectory() throws {
        let store = AttachmentPreviewStore()
        let fileURL = try store.writePreviewFile(data: Data([0x01]), filename: "sample.bin")
        let directory = fileURL.deletingLastPathComponent()

        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))

        store.deletePreviewFile(at: fileURL)

        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testQuickLookPreviewSourceIsAvailableOnIOS() throws {
        let source = try Self.quickLookPreviewSource()

        XCTAssertTrue(source.contains("QLPreviewController"))
        XCTAssertTrue(source.contains("#if os(iOS)"))
    }

    private static func quickLookPreviewSource() throws -> String {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = packageRoot
            .appendingPathComponent("Sources/NotesFlow/Attachments/QuickLookPreview.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
