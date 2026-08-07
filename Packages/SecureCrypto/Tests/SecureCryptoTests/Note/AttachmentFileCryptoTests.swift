import CryptoKit
import XCTest

@testable import SecureCrypto

final class AttachmentFileCryptoTests: XCTestCase {
    func testAttachmentEncryptDecryptRoundtrip() throws {
        let fek = generateSymmetricKey()
        let plaintext = Data((0 ..< 256).map(UInt8.init))

        let ciphertext = try encryptAttachmentFile(plaintext, with: fek)
        let decrypted = try decryptAttachmentFile(ciphertext, with: fek)

        XCTAssertEqual(decrypted, plaintext)
        XCTAssertNotEqual(ciphertext, plaintext)
    }

    func testAttachmentDecryptRejectsWrongFEK() throws {
        let fek = generateSymmetricKey()
        let wrongFEK = generateSymmetricKey()
        let plaintext = Data("attachment-bytes".utf8)

        let ciphertext = try encryptAttachmentFile(plaintext, with: fek)

        XCTAssertThrowsError(try decryptAttachmentFile(ciphertext, with: wrongFEK)) { error in
            XCTAssertEqual(error as? SecureCryptoError, .authenticationFailed)
        }
    }
}
