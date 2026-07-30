import AuthFlowUI
import Foundation
import XCTest

@testable import AuthFlowUI

@MainActor
final class BiometricEnrollmentViewTests: XCTestCase {
    func testBiometricEnrollmentViewIsPubliclyConstructible() {
        let deps = PreviewSupport.makeDependencies()
        _ = BiometricEnrollmentView(
            viewModel: deps.makeBiometricEnrollmentViewModel(onComplete: {})
        )
    }

    func testEnrollmentShownAfterFirstLogin() throws {
        let loginSource = try Self.loginViewSource()
        XCTAssertTrue(loginSource.contains("pendingBiometricEnrollment"))
        XCTAssertTrue(loginSource.contains(".sheet"))
        XCTAssertTrue(loginSource.contains("BiometricEnrollmentView"))

        let registerSource = try Self.registerViewSource()
        XCTAssertTrue(registerSource.contains("pendingBiometricEnrollment"))
        XCTAssertTrue(registerSource.contains("BiometricEnrollmentView"))
    }

    func testEnrollmentNotShownOnSubsequentUnlocks() throws {
        let unlockSource = try Self.unlockViewSource()

        XCTAssertFalse(unlockSource.contains("BiometricEnrollmentView"))
        XCTAssertFalse(unlockSource.contains("pendingBiometricEnrollment"))
    }

    func testBioEnrollmentStringsAreLocalized() throws {
        let catalog = try Self.loadStringCatalog()
        let keys = [
            "bio.enrollment.title",
            "bio.enrollment.message",
            "bio.enrollment.password",
            "bio.enrollment.enable",
            "bio.enrollment.skip",
        ]

        for key in keys {
            XCTAssertNotNil(catalog.strings[key], "Missing localization key: \(key)")
            XCTAssertFalse(catalog.strings[key]?.localizations["en"]?.stringUnit.value.isEmpty ?? true)
        }
    }

    private static func loginViewSource() throws -> String {
        try viewSource(named: "LoginView.swift")
    }

    private static func registerViewSource() throws -> String {
        try viewSource(named: "RegisterView.swift")
    }

    private static func unlockViewSource() throws -> String {
        try viewSource(named: "UnlockView.swift")
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
