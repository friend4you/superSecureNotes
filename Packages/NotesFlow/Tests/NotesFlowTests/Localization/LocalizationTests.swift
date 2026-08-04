import Foundation
import NotesFlow
import XCTest

@testable import NotesFlow

final class LocalizationTests: XCTestCase {
    func testStringCatalogIsBundledWithNotesFlow() {
        XCTAssertTrue(NotesFlowUIBundleTesting.hasLocalizedCatalog)
    }

    func testAttachmentLocalizationKeysExist() throws {
        let catalog = try Self.loadStringCatalog()
        let keys = [
            "notes.attachments.remove",
            "notes.attachments.preview",
            "notes.detail.attachments",
            "notes.sync.pending",
            "notes.sync.synced",
            "common.close",
        ]

        for key in keys {
            XCTAssertNotNil(catalog.strings[key], "Missing localization key: \(key)")
            XCTAssertFalse(catalog.strings[key]?.localizations["en"]?.stringUnit.value.isEmpty ?? true)
        }
    }

    private static func loadStringCatalog() throws -> StringCatalog {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = packageRoot
            .appendingPathComponent("Sources/NotesFlow/Resources/Localizable.xcstrings")
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
