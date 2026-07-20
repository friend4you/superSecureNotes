import CryptoKit
import XCTest

@testable import SecureCrypto

final class ChaChaPolyCipherTests: XCTestCase {
    func testChaChaPolyCipherConformsToSymmetricCipher() throws {
        let cipher = ChaChaPolyCipher()
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("protocol impl".utf8)

        let ciphertext = try cipher.encrypt(plaintext, key: key)
        let decrypted = try cipher.decrypt(ciphertext, key: key)

        XCTAssertEqual(decrypted, plaintext)
    }

    func testChaChaPolyCipherRejectsTamperedCiphertext() throws {
        let cipher = ChaChaPolyCipher()
        let key = SymmetricKey(size: .bits256)
        var ciphertext = try cipher.encrypt(Data("tamper".utf8), key: key)
        ciphertext[ciphertext.count - 1] ^= 0xFF

        XCTAssertThrowsError(try cipher.decrypt(ciphertext, key: key)) { error in
            XCTAssertEqual(error as? SecureCryptoError, .authenticationFailed)
        }
    }

    func testEncryptDecryptRoundtrip() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("super secure note body".utf8)

        let ciphertext = try encrypt(plaintext, key: key)
        let decrypted = try decrypt(ciphertext, key: key)

        XCTAssertEqual(decrypted, plaintext)
    }

    func testCiphertextIncludesNonceAndTag() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("payload".utf8)

        let ciphertext = try encrypt(plaintext, key: key)

        XCTAssertEqual(ciphertext.count, plaintext.count + 12 + 16)
    }

    func testTamperedCiphertextIsRejected() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("tamper me".utf8)
        var ciphertext = try encrypt(plaintext, key: key)
        ciphertext[ciphertext.count - 1] ^= 0xFF

        XCTAssertThrowsError(try decrypt(ciphertext, key: key)) { error in
            XCTAssertEqual(error as? SecureCryptoError, .authenticationFailed)
        }
    }

    func testDifferentEncryptionsUseUniqueNonces() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("repeat".utf8)

        let first = try encrypt(plaintext, key: key)
        let second = try encrypt(plaintext, key: key)

        XCTAssertNotEqual(first, second)
    }
}
