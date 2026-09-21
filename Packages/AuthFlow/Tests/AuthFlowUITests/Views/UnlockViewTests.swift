import AuthFlowUI
import XCTest

@testable import AuthFlowUI

@MainActor
final class UnlockViewTests: XCTestCase {
    func testUnlockViewUsesSectionBuilders() throws {
        let source = try Self.viewSource(named: "UnlockView.swift")
        XCTAssertTrue(source.contains("credentialsSection"))
        XCTAssertTrue(source.contains("errorSection"))
        XCTAssertTrue(source.contains("actionsSection"))
    }

    func testUnlockViewShowsLoadingIndicatorDuringRequest() throws {
        let source = try Self.viewSource(named: "UnlockView.swift")
        XCTAssertTrue(source.contains("AuthLoadingSection()"))
        XCTAssertTrue(source.contains("showsLoadingIndicator"))
        XCTAssertTrue(source.contains("viewModel.isLoggingOut"))
    }

    private static func viewSource(named fileName: String) throws -> String {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = packageRoot
            .appendingPathComponent("Sources/AuthFlowUI/Views")
            .appendingPathComponent(fileName)
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
