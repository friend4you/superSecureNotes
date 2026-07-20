import CryptoKit
import XCTest

@testable import SecureCryptoProtocol

final class SymmetricCipherTests: XCTestCase {
    func testMockEncryptDecryptRoundtrip() throws {
        let cipher = MockSymmetricCipher()
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("protocol contract".utf8)

        let ciphertext = try cipher.encrypt(plaintext, key: key)
        let decrypted = try cipher.decrypt(ciphertext, key: key)

        XCTAssertEqual(decrypted, plaintext)
    }
}

private struct MockSymmetricCipher: SymmetricCipher {
    func encrypt(_ plaintext: Data, key: SymmetricKey) throws -> Data {
        plaintext
    }

    func decrypt(_ ciphertext: Data, key: SymmetricKey) throws -> Data {
        ciphertext
    }
}
