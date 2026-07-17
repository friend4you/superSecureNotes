import XCTest

@testable import SecureCrypto

final class BIP39MnemonicValidationTests: XCTestCase {
    func testValidateAcceptsKnownGoodPhrase() throws {
        let words = try BIP39Mnemonic.words(from: Data(repeating: 0x00, count: 16))

        let entropy = try BIP39Mnemonic.validate(words)

        XCTAssertEqual(entropy, Data(repeating: 0x00, count: 16))
    }

    func testRejectsWrongWordCount() {
        let words = Array(repeating: "abandon", count: 11)

        XCTAssertThrowsError(try BIP39Mnemonic.validate(words)) { error in
            XCTAssertEqual(error as? SecureCryptoError, .invalidInput("Mnemonic must contain exactly 12 words."))
        }
    }

    func testRejectsInvalidChecksum() {
        let words = Array(repeating: "abandon", count: 12)

        XCTAssertThrowsError(try BIP39Mnemonic.validate(words)) { error in
            XCTAssertEqual(error as? SecureCryptoError, .invalidInput("Mnemonic checksum is invalid."))
        }
    }

    func testRejectsUnknownWord() {
        let words = [
            "abandon", "abandon", "abandon", "abandon", "abandon", "abandon",
            "abandon", "abandon", "abandon", "abandon", "abandon", "notaword",
        ]

        XCTAssertThrowsError(try BIP39Mnemonic.validate(words)) { error in
            XCTAssertEqual(error as? SecureCryptoError, .invalidInput("Mnemonic contains unknown word: notaword"))
        }
    }
}
