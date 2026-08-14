import AuthFlowUI
import Foundation
import XCTest

@testable import AuthFlowUI

@MainActor
final class BiometricEnrollmentViewTests: XCTestCase {
    func testBiometricEnrollmentViewIsPubliclyConstructible() {
        let deps = PreviewSupport.makeDependencies()
        _ = BiometricEnrollmentView(
            viewModel: deps.makeBiometricEnrollmentViewModel()
        )
    }

    func testLoginViewHasNoEnrollmentSheet() throws {
        let loginSource = try Self.viewSource(named: "LoginView.swift")
        XCTAssertFalse(loginSource.contains(".sheet"))
        XCTAssertFalse(loginSource.contains("pendingBiometricEnrollment"))
        XCTAssertFalse(loginSource.contains("BiometricEnrollmentView"))
    }

    func testRegisterViewHasNoEnrollmentSheet() throws {
        let registerSource = try Self.viewSource(named: "RegisterView.swift")
        XCTAssertFalse(registerSource.contains(".sheet"))
        XCTAssertFalse(registerSource.contains("pendingBiometricEnrollment"))
        XCTAssertFalse(registerSource.contains("BiometricEnrollmentView"))
    }

    func testEnrollmentNotShownOnSubsequentUnlocks() throws {
        let unlockSource = try Self.viewSource(named: "UnlockView.swift")

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
