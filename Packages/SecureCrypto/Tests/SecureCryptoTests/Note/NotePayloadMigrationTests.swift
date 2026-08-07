import CryptoKit
import XCTest

@testable import SecureCrypto

final class NotePayloadMigrationTests: XCTestCase {
    func testDecryptV1InlineAttachmentPayload() throws {
        let fek = generateSymmetricKey()
        let payload = NotePayload(
            body: Data("legacy body".utf8),
            attachments: [
                NotePayload.Attachment(
                    id: "old-id-1",
                    filename: "photo.png",
                    mime: "image/png",
                    data: Data([0x89, 0x50, 0x4E, 0x47])
                ),
            ]
        )

        let encrypted = try encryptPayload(payload, with: fek)
        let decrypted = try decryptPayload(encrypted, with: fek)

        XCTAssertEqual(decrypted.schemaVersion, 1)
        XCTAssertEqual(decrypted.body, payload.body)
        XCTAssertEqual(decrypted.attachments.count, 1)
        XCTAssertEqual(decrypted.attachments[0].id, "old-id-1")
        XCTAssertEqual(decrypted.attachments[0].data, Data([0x89, 0x50, 0x4E, 0x47]))
    }

    func testDecryptV1PayloadWithoutSchemaVersionField() throws {
        let fek = generateSymmetricKey()
        let legacyJSON: [String: Any] = [
            "body": Data("no version".utf8).base64EncodedString(),
            "attachments": [
                [
                    "id": "att-1",
                    "filename": "a.bin",
                    "mime": "application/octet-stream",
                    "data": Data([0x01, 0x02]).base64EncodedString(),
                ],
            ],
        ]
        let plaintext = try JSONSerialization.data(withJSONObject: legacyJSON)
        let encrypted = try encrypt(plaintext, key: fek)

        let decrypted = try decryptPayload(encrypted, with: fek)

        XCTAssertEqual(decrypted.schemaVersion, 1)
        XCTAssertEqual(decrypted.body, Data("no version".utf8))
        XCTAssertEqual(decrypted.attachments[0].data, Data([0x01, 0x02]))
    }

    func testMigratePayloadV1ToV2RegeneratesUUIDs() throws {
        let v1 = NotePayload(
            body: Data("migrate me".utf8),
            attachments: [
                NotePayload.Attachment(
                    id: "legacy-string-id",
                    filename: "receipt.pdf",
                    mime: "application/pdf",
                    data: Data([0x25, 0x50, 0x44, 0x46])
                ),
                NotePayload.Attachment(
                    id: "another-old-id",
                    filename: "photo.jpg",
                    mime: "image/jpeg",
                    data: Data([0xFF, 0xD8])
                ),
            ]
        )

        let migrated = try migratePayloadV1ToV2(v1)

        XCTAssertEqual(migrated.payload.schemaVersion, 2)
        XCTAssertEqual(migrated.payload.body, v1.body)
        XCTAssertEqual(migrated.payload.attachments.count, 2)
        XCTAssertEqual(migrated.attachmentBytes.count, 2)

        for (index, entry) in migrated.payload.attachments.enumerated() {
            XCTAssertNil(entry.data)
            XCTAssertNotEqual(entry.id, v1.attachments[index].id)
            XCTAssertNotNil(UUID(uuidString: entry.id))
            XCTAssertEqual(entry.filename, v1.attachments[index].filename)
            XCTAssertEqual(entry.mime, v1.attachments[index].mime)
            XCTAssertEqual(entry.size, v1.attachments[index].data?.count)
            XCTAssertEqual(migrated.attachmentBytes[entry.id], v1.attachments[index].data)
        }

        let encoded = try JSONEncoder().encode(migrated.payload)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let attachments = try XCTUnwrap(json["attachments"] as? [[String: Any]])
        for entry in attachments {
            XCTAssertNil(entry["data"])
        }
    }
}
