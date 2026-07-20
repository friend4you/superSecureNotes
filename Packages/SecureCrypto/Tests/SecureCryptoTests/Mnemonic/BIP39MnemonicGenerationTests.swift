import XCTest

@testable import SecureCrypto

final class BIP39MnemonicGenerationTests: XCTestCase {
    func testGeneratesTwelveWordsFrom128BitEntropy() throws {
        let entropy = Data(repeating: 0x7f, count: 16)

        let words = try BIP39Mnemonic.words(from: entropy)

        XCTAssertEqual(words.count, 12)
        XCTAssertTrue(words.allSatisfy { BIP39Wordlist.contains($0) })
    }

    func testKnownVectorAllZerosEntropy() throws {
        let entropy = Data(repeating: 0x00, count: 16)

        let words = try BIP39Mnemonic.words(from: entropy)

        XCTAssertEqual(
            words,
            [
                "abandon", "abandon", "abandon", "abandon", "abandon", "abandon",
                "abandon", "abandon", "abandon", "abandon", "abandon", "about",
            ]
        )
    }

    func testKnownVectorRepeated7FEntropy() throws {
        let entropy = Data(repeating: 0x7f, count: 16)

        let words = try BIP39Mnemonic.words(from: entropy)

        XCTAssertEqual(
            words,
            [
                "legal", "winner", "thank", "year", "wave", "sausage",
                "worth", "useful", "legal", "winner", "thank", "yellow",
            ]
        )
    }

    func testRejectsEntropyThatIsNot128Bits() {
        XCTAssertThrowsError(try BIP39Mnemonic.words(from: Data(repeating: 0, count: 15))) { error in
            XCTAssertEqual(error as? SecureCryptoError, .invalidInput("Mnemonic entropy must be exactly 16 bytes."))
        }
    }
}
