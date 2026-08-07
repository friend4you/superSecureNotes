import CryptoKit
import XCTest

@testable import SecureCrypto

final class NotePayloadV2Tests: XCTestCase {
    func testV2PayloadEncodesSchemaVersion() throws {
        let payload = NotePayload(
            body: Data("hello".utf8),
            attachments: [
                NotePayload.Attachment(
                    id: "550e8400-e29b-41d4-a716-446655440000",
                    filename: "receipt.pdf",
                    mime: "application/pdf",
                    size: 12_345
                ),
            ],
            schemaVersion: 2
        )

        let encoded = try JSONEncoder().encode(payload)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

        XCTAssertEqual(json["schemaVersion"] as? Int, 2)
    }

    func testV2AttachmentIndexExcludesDataField() throws {
        let payload = NotePayload(
            body: Data("hello".utf8),
            attachments: [
                NotePayload.Attachment(
                    id: "550e8400-e29b-41d4-a716-446655440000",
                    filename: "receipt.pdf",
                    mime: "application/pdf",
                    size: 12_345
                ),
            ],
            schemaVersion: 2
        )

        let encoded = try JSONEncoder().encode(payload)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let attachments = try XCTUnwrap(json["attachments"] as? [[String: Any]])
        let entry = try XCTUnwrap(attachments.first)

        XCTAssertNil(entry["data"])
        XCTAssertEqual(entry["id"] as? String, "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(entry["filename"] as? String, "receipt.pdf")
        XCTAssertEqual(entry["mime"] as? String, "application/pdf")
        XCTAssertEqual(entry["size"] as? Int, 12_345)
    }

    func testEncryptAndDecryptV2PayloadRoundtrip() throws {
        let fek = generateSymmetricKey()
        let payload = NotePayload(
            body: Data("secret note body".utf8),
            attachments: [
                NotePayload.Attachment(
                    id: "550e8400-e29b-41d4-a716-446655440000",
                    filename: "photo.png",
                    mime: "image/png",
                    size: 4
                ),
            ],
            schemaVersion: 2
        )

        let encrypted = try encryptPayload(payload, with: fek)
        let decrypted = try decryptPayload(encrypted, with: fek)

        XCTAssertEqual(decrypted.schemaVersion, 2)
        XCTAssertEqual(decrypted.body, payload.body)
        XCTAssertEqual(decrypted.attachments.count, 1)
        XCTAssertEqual(decrypted.attachments[0].id, payload.attachments[0].id)
        XCTAssertEqual(decrypted.attachments[0].filename, payload.attachments[0].filename)
        XCTAssertEqual(decrypted.attachments[0].mime, payload.attachments[0].mime)
        XCTAssertEqual(decrypted.attachments[0].size, 4)
        XCTAssertNil(decrypted.attachments[0].data)
    }
}
