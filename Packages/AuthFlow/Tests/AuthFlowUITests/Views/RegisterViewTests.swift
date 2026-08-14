import AuthFlowUI
import XCTest

@testable import AuthFlowUI

@MainActor
final class RegisterViewTests: XCTestCase {
    func testRegisterViewUsesSectionBuilders() throws {
        let source = try Self.viewSource(named: "RegisterView.swift")
        XCTAssertTrue(source.contains("credentialsSection"))
        XCTAssertTrue(source.contains("errorSection"))
        XCTAssertTrue(source.contains("actionsSection"))
        XCTAssertFalse(source.contains(".sheet"))
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
