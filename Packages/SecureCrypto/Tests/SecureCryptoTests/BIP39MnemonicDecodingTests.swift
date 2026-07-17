import XCTest

@testable import SecureCrypto

final class BIP39MnemonicDecodingTests: XCTestCase {
    func testEntropyRoundtripFromGeneratedWords() throws {
        let entropy = Data([
            0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0,
            0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88,
        ])

        let words = try BIP39Mnemonic.words(from: entropy)
        let decoded = try BIP39Mnemonic.entropy(from: words)

        XCTAssertEqual(decoded, entropy)
    }

    func testEntropyDecodingMatchesValidation() throws {
        let words = try BIP39Mnemonic.words(from: Data(repeating: 0x80, count: 16))

        let validated = try BIP39Mnemonic.validate(words)
        let decoded = try BIP39Mnemonic.entropy(from: words)

        XCTAssertEqual(decoded, validated)
    }
}
