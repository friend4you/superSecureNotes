import XCTest

@testable import SecureCrypto

final class BIP39MnemonicEncoderTests: XCTestCase {
    private let encoder = BIP39MnemonicEncoder()

    func testConformsToMnemonicEncodingGeneration() throws {
        let entropy = Data(repeating: 0x7f, count: 16)

        let words = try encoder.words(from: entropy)

        XCTAssertEqual(words.count, encoder.wordCount)
        XCTAssertTrue(words.allSatisfy { BIP39Wordlist.contains($0) })
    }

    func testConformsToMnemonicEncodingValidation() throws {
        let words = try encoder.words(from: Data(repeating: 0x00, count: 16))

        let entropy = try encoder.validate(words)

        XCTAssertEqual(entropy, Data(repeating: 0x00, count: 16))
    }

    func testRejectsInvalidChecksum() {
        let words = Array(repeating: "abandon", count: 12)

        XCTAssertThrowsError(try encoder.validate(words)) { error in
            XCTAssertEqual(error as? SecureCryptoError, .invalidInput("Mnemonic checksum is invalid."))
        }
    }

    func testRejectsWrongWordCount() {
        let words = Array(repeating: "abandon", count: 11)

        XCTAssertThrowsError(try encoder.validate(words)) { error in
            XCTAssertEqual(error as? SecureCryptoError, .invalidInput("Mnemonic must contain exactly 12 words."))
        }
    }

    func testEntropyRoundtrip() throws {
        let entropy = Data([
            0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0,
            0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88,
        ])

        let words = try encoder.words(from: entropy)
        let decoded = try encoder.entropy(from: words)

        XCTAssertEqual(decoded, entropy)
    }
}
