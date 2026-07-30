import AuthFlowUI
import Foundation
import XCTest

@testable import AuthFlowUI

@MainActor
final class UnlockViewTests: XCTestCase {
    func testUnlockViewIsPubliclyConstructible() {
        let deps = PreviewSupport.makeDependencies()
        _ = UnlockView(viewModel: deps.makeUnlockViewModel())
    }

    func testEmailIsReadOnlyOnUnlock() throws {
        let source = try Self.unlockViewSource()

        XCTAssertTrue(source.contains("Text(viewModel.email)"))
        XCTAssertFalse(source.contains("TextField"))
        XCTAssertFalse(source.contains("$viewModel.email"))
    }

    func testUnlockStringsAreLocalized() throws {
        let catalog = try Self.loadStringCatalog()
        let keys = [
            "unlock.title",
            "unlock.password",
            "unlock.submit",
            "unlock.useBiometrics",
        ]

        for key in keys {
            XCTAssertNotNil(catalog.strings[key], "Missing localization key: \(key)")
            XCTAssertFalse(catalog.strings[key]?.localizations["en"]?.stringUnit.value.isEmpty ?? true)
        }
    }

    private static func unlockViewSource() throws -> String {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Views
            .deletingLastPathComponent() // AuthFlowUITests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // AuthFlow package root
        let sourceURL = packageRoot
            .appendingPathComponent("Sources/AuthFlowUI/Views/UnlockView.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }

    private static func loadStringCatalog() throws -> StringCatalog {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Views
            .deletingLastPathComponent() // AuthFlowUITests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // AuthFlow package root
        let catalogURL = packageRoot
            .appendingPathComponent("Sources/AuthFlowUI/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        return try JSONDecoder().decode(StringCatalog.self, from: data)
    }
}

private struct StringCatalog: Decodable {
    struct Entry: Decodable {
        struct Localization: Decodable {
            struct StringUnit: Decodable {
                let value: String
            }

            let stringUnit: StringUnit
        }

        let localizations: [String: Localization]
    }

    let strings: [String: Entry]
}
