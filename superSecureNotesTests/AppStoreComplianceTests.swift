import XCTest

final class AppStoreComplianceTests: XCTestCase {
    func testProjectTargetsIPhoneOnly() throws {
        let projectContents = try Self.projectContents()
        let appTargetSections = Self.appTargetBuildSettingsSections(from: projectContents)

        XCTAssertEqual(appTargetSections.count, 2)
        for section in appTargetSections {
            XCTAssertTrue(
                section.contains("TARGETED_DEVICE_FAMILY = 1;"),
                "App target must be iPhone-only"
            )
        }
    }

    func testProjectDeclaresFaceIDUsageDescription() throws {
        let projectContents = try Self.projectContents()
        let appTargetSections = Self.appTargetBuildSettingsSections(from: projectContents)

        XCTAssertEqual(appTargetSections.count, 2)
        for section in appTargetSections {
            XCTAssertTrue(
                section.contains("INFOPLIST_KEY_NSFaceIDUsageDescription"),
                "Face ID usage description must be configured"
            )
        }
    }

    func testProjectDeclaresDisplayName() throws {
        let projectContents = try Self.projectContents()
        let appTargetSections = Self.appTargetBuildSettingsSections(from: projectContents)

        XCTAssertEqual(appTargetSections.count, 2)
        for section in appTargetSections {
            XCTAssertTrue(
                section.contains("INFOPLIST_KEY_CFBundleDisplayName = \"Super Secure Notes\";"),
                "Display name must be Super Secure Notes"
            )
        }
    }

    func testPrivacyManifestDeclaresUserDefaultsCA921() throws {
        let manifestURL = try Self.repoRoot()
            .appendingPathComponent("superSecureNotes/PrivacyInfo.xcprivacy")
        let manifest = try String(contentsOf: manifestURL, encoding: .utf8)

        XCTAssertTrue(manifest.contains("NSPrivacyAccessedAPICategoryUserDefaults"))
        XCTAssertTrue(manifest.contains("CA92.1"))
    }

    func testAppIconHasNoAlphaChannel() throws {
        let iconURL = try Self.repoRoot()
            .appendingPathComponent("superSecureNotes/Assets.xcassets/AppIcon.appiconset/secure_note_icon.png")
        let data = try Data(contentsOf: iconURL)
        let pngSignature = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

        XCTAssertGreaterThanOrEqual(data.count, 26)
        XCTAssertEqual(data.prefix(8), pngSignature)

        // IHDR color type: 2 = RGB, 6 = RGBA
        let colorType = data[25]
        XCTAssertEqual(colorType, 2, "App icon must be RGB without an alpha channel")
    }

    private static func repoRoot() throws -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static func projectContents() throws -> String {
        let projectURL = try repoRoot()
            .appendingPathComponent("superSecureNotes.xcodeproj/project.pbxproj")
        return try String(contentsOf: projectURL, encoding: .utf8)
    }

    private static func appTargetBuildSettingsSections(from projectContents: String) -> [String] {
        [
            "AA611E7430094D0800F15876 /* Debug */",
            "AA611E7530094D0800F15876 /* Release */",
        ].compactMap { configurationMarker in
            guard let configRange = projectContents.range(of: "\(configurationMarker) = {") else {
                return nil
            }
            let configTail = projectContents[configRange.upperBound...]
            guard let settingsStart = configTail.range(of: "buildSettings = {")?.upperBound,
                  let settingsEnd = configTail[settingsStart...].range(of: "};")?.lowerBound else {
                return nil
            }
            return String(configTail[settingsStart..<settingsEnd])
        }
    }
}
