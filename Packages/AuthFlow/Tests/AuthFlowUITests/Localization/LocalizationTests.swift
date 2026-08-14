import AuthFlowUI
import XCTest

@testable import AuthFlowUI

final class LocalizationTests: XCTestCase {
    func testStringCatalogIsBundledWithAuthFlowUI() {
        XCTAssertTrue(AuthFlowUIBundleTesting.hasLocalizedCatalog)
    }

    func testViewsDoNotReferenceAuthFlowUILocalization() throws {
        let viewsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/AuthFlowUI/Views")

        let viewFiles = try FileManager.default.contentsOfDirectory(
            at: viewsDirectory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "swift" }

        for file in viewFiles {
            let source = try String(contentsOf: file, encoding: .utf8)
            XCTAssertFalse(
                source.contains("AuthFlowUILocalization"),
                "\(file.lastPathComponent) should not reference AuthFlowUILocalization"
            )
        }
    }
}
