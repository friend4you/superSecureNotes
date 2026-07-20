import CryptoKit
import XCTest

@testable import SecureCrypto

final class NoteEncryptionTests: XCTestCase {
    func testWrapAndUnwrapFEKRoundtrip() throws {
        let udk = generateSymmetricKey()
        let fek = generateSymmetricKey()

        let wrappedFEK = try wrapFEK(fek, with: udk)
        let unwrappedFEK = try unwrapFEK(wrappedFEK, with: udk)

        XCTAssertEqual(keyData(unwrappedFEK), keyData(fek))
    }

    func testUnwrapFEKRejectsWrongUDK() throws {
        let udk = generateSymmetricKey()
        let wrongUDK = generateSymmetricKey()
        let fek = generateSymmetricKey()

        let wrappedFEK = try wrapFEK(fek, with: udk)

        XCTAssertThrowsError(try unwrapFEK(wrappedFEK, with: wrongUDK)) { error in
            XCTAssertEqual(error as? SecureCryptoError, .authenticationFailed)
        }
    }

    func testEncryptAndDecryptPayloadRoundtrip() throws {
        let fek = generateSymmetricKey()
        let payload = NotePayload(
            body: Data("secret note body".utf8),
            attachments: [
                NotePayload.Attachment(
                    id: "550e8400-e29b-41d4-a716-446655440000",
                    filename: "photo.png",
                    mime: "image/png",
                    data: Data([0x89, 0x50, 0x4E, 0x47])
                ),
            ]
        )

        let encrypted = try encryptPayload(payload, with: fek)
        let decrypted = try decryptPayload(encrypted, with: fek)

        XCTAssertEqual(decrypted, payload)
    }

    func testEncryptAndDecryptPayloadWithEmptyAttachments() throws {
        let fek = generateSymmetricKey()
        let payload = NotePayload(body: Data("plain text".utf8))

        let encrypted = try encryptPayload(payload, with: fek)
        let decrypted = try decryptPayload(encrypted, with: fek)

        XCTAssertEqual(decrypted.attachments, [])
        XCTAssertEqual(decrypted.body, payload.body)
    }

    func testDecryptPayloadRejectsWrongFEK() throws {
        let fek = generateSymmetricKey()
        let wrongFEK = generateSymmetricKey()
        let payload = NotePayload(body: Data("secret".utf8))

        let encrypted = try encryptPayload(payload, with: fek)

        XCTAssertThrowsError(try decryptPayload(encrypted, with: wrongFEK)) { error in
            XCTAssertEqual(error as? SecureCryptoError, .authenticationFailed)
        }
    }

    private func keyData(_ key: SymmetricKey) -> Data {
        key.withUnsafeBytes { Data($0) }
    }
}
