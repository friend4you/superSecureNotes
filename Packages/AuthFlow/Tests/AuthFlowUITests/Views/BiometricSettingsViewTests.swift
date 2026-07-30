import AuthFlowUI
import Foundation
import XCTest

@testable import AuthFlowUI

@MainActor
final class BiometricSettingsViewTests: XCTestCase {
    func testBiometricSettingsViewIsPubliclyConstructible() {
        let deps = PreviewSupport.makeDependencies()
        _ = BiometricSettingsView(viewModel: deps.makeBiometricSettingsViewModel())
    }

    func testToggleWiresToBiometricSettingsViewModel() throws {
        let source = try Self.biometricSettingsViewSource()

        XCTAssertTrue(source.contains("Toggle("))
        XCTAssertTrue(source.contains("viewModel.isBiometricsEnabled"))
        XCTAssertTrue(source.contains("viewModel.enableBiometrics()"))
        XCTAssertTrue(source.contains("viewModel.disableBiometrics()"))
        XCTAssertTrue(source.contains("requiresPasswordConfirmation"))
        XCTAssertTrue(source.contains("$viewModel.password"))
    }

    func testBioSettingsStringsAreLocalized() throws {
        let catalog = try Self.loadStringCatalog()
        let keys = [
            "bio.settings.title",
            "bio.settings.toggle",
            "bio.settings.password",
        ]

        for key in keys {
            XCTAssertNotNil(catalog.strings[key], "Missing localization key: \(key)")
            XCTAssertFalse(catalog.strings[key]?.localizations["en"]?.stringUnit.value.isEmpty ?? true)
        }
    }

    private static func biometricSettingsViewSource() throws -> String {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Views
            .deletingLastPathComponent() // AuthFlowUITests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // AuthFlow package root
        let sourceURL = packageRoot
            .appendingPathComponent("Sources/AuthFlowUI/Views/BiometricSettingsView.swift")
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
