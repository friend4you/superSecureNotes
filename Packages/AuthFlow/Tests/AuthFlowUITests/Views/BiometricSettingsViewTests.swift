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

    func testBiometricSettingsViewSourceWrapsNavigationStackWithDoneDismiss() throws {
        let source = try Self.biometricSettingsViewSource()

        XCTAssertTrue(source.contains("NavigationStack {"))
        XCTAssertTrue(source.contains("ToolbarItem(placement: .cancellationAction)"))
        XCTAssertTrue(source.contains("bio.settings.done"))
        XCTAssertTrue(source.contains("viewModel.dismiss()"))
    }

    func testBiometricSettingsViewSourceHasLogoutWithoutDebugGuard() throws {
        let source = try Self.biometricSettingsViewSource()

        XCTAssertTrue(source.contains("bio.settings.logout"))
        XCTAssertTrue(source.contains("viewModel.logout()"))
        XCTAssertFalse(source.contains("#if DEBUG"))
    }

    func testBiometricSettingsViewSourceShowsLoadingDuringDestructiveActions() throws {
        let source = try Self.biometricSettingsViewSource()

        XCTAssertTrue(source.contains("AuthLoadingSection()"))
        XCTAssertTrue(source.contains("viewModel.isDeletingAccount"))
        XCTAssertTrue(source.contains("viewModel.isLoggingOut"))
    }

    func testBiometricSettingsViewSourceHasDeleteAccountFlow() throws {
        let source = try Self.biometricSettingsViewSource()

        XCTAssertTrue(source.contains("bio.settings.deleteAccount"))
        XCTAssertTrue(source.contains("viewModel.beginDeleteAccount()"))
        XCTAssertTrue(source.contains("viewModel.deleteAccount()"))
        XCTAssertTrue(source.contains("confirmationDialog"))
        XCTAssertTrue(source.contains("bio.settings.deleteAccount.password"))
    }

    func testBiometricSettingsViewSourceHasLegalAndSupportLinks() throws {
        let source = try Self.biometricSettingsViewSource()

        XCTAssertTrue(source.contains("bio.settings.privacyPolicy"))
        XCTAssertTrue(source.contains("AuthLegalLinks.privacyPolicyURL"))
        XCTAssertTrue(source.contains("SupportContactRow()"))
    }

    func testSupportContactRowOpensMailtoWithFallback() throws {
        let source = try Self.supportContactRowSource()

        XCTAssertTrue(source.contains("AuthLegalLinks.supportEmailURL"))
        XCTAssertTrue(source.contains("openURL(AuthLegalLinks.supportEmailURL)"))
        XCTAssertTrue(source.contains("AuthLegalLinks.supportEmailAddress"))
        XCTAssertTrue(source.contains("bio.settings.support.unavailable"))
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
            "bio.settings.done",
            "bio.settings.logout",
            "bio.settings.deleteAccount",
            "bio.settings.deleteAccount.confirm",
            "bio.settings.deleteAccount.message",
            "bio.settings.deleteAccount.password",
            "bio.settings.deleteAccount.confirmButton",
            "bio.settings.deleteAccount.cancel",
            "bio.settings.privacyPolicy",
            "bio.settings.support",
            "bio.settings.support.unavailable.title",
            "bio.settings.support.unavailable.message",
        ]

        for key in keys {
            XCTAssertNotNil(catalog.strings[key], "Missing localization key: \(key)")
            XCTAssertFalse(catalog.strings[key]?.localizations["en"]?.stringUnit.value.isEmpty ?? true)
        }
    }

    private static func biometricSettingsViewSource() throws -> String {
        try viewSource(named: "BiometricSettingsView.swift")
    }

    private static func supportContactRowSource() throws -> String {
        try viewSource(named: "SupportContactRow.swift")
    }

    private static func viewSource(named fileName: String) throws -> String {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Views
            .deletingLastPathComponent() // AuthFlowUITests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // AuthFlow package root
        let sourceURL = packageRoot
            .appendingPathComponent("Sources/AuthFlowUI/Views")
            .appendingPathComponent(fileName)
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
