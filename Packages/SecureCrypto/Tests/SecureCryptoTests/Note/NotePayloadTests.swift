import XCTest

@testable import SecureCrypto

final class NotePayloadTests: XCTestCase {
    func testEncodesAndDecodesBodyAndAttachments() throws {
        let payload = NotePayload(
            body: Data("hello".utf8),
            attachments: [
                NotePayload.Attachment(
                    id: "550e8400-e29b-41d4-a716-446655440000",
                    filename: "photo.png",
                    mime: "image/png",
                    data: Data([0x89, 0x50, 0x4E, 0x47])
                ),
            ]
        )

        let encoded = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(NotePayload.self, from: encoded)

        XCTAssertEqual(decoded, payload)
    }

    func testEmptyAttachmentsArray() throws {
        let payload = NotePayload(body: Data("plain text".utf8))

        let encoded = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(NotePayload.self, from: encoded)

        XCTAssertEqual(decoded.attachments, [])
        XCTAssertEqual(decoded.body, payload.body)
    }
}
