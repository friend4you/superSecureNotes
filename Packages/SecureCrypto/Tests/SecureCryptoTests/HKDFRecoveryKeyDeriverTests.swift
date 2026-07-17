import CryptoKit
import XCTest

@testable import SecureCrypto

final class HKDFRecoveryKeyDeriverTests: XCTestCase {
    func testDeriveKeyFrom128BitEntropyReturns256BitKey() throws {
        let deriver = HKDFRecoveryKeyDeriver()
        let entropy = Data([
            0x7A, 0xB3, 0x9F, 0x22, 0xC1, 0x8D, 0x44, 0x90,
            0xE6, 0x05, 0x31, 0x77, 0x4C, 0xA8, 0x12, 0x5E,
        ])

        let key = try deriver.deriveKey(entropy: entropy)

        XCTAssertEqual(key.bitCount, 256)
    }

    func testDerivationIsDeterministicForSameEntropy() throws {
        let deriver = HKDFRecoveryKeyDeriver()
        let entropy = Data(repeating: 0xAB, count: 16)

        let first = try deriver.deriveKey(entropy: entropy)
        let second = try deriver.deriveKey(entropy: entropy)

        XCTAssertEqual(keyData(first), keyData(second))
    }

    func testDifferentEntropyProducesDifferentKeys() throws {
        let deriver = HKDFRecoveryKeyDeriver()
        let firstEntropy = Data(repeating: 0x01, count: 16)
        let secondEntropy = Data(repeating: 0x02, count: 16)

        let first = try deriver.deriveKey(entropy: firstEntropy)
        let second = try deriver.deriveKey(entropy: secondEntropy)

        XCTAssertNotEqual(keyData(first), keyData(second))
    }

    func testRejectsEntropyThatIsNot128Bits() {
        let deriver = HKDFRecoveryKeyDeriver()

        XCTAssertThrowsError(try deriver.deriveKey(entropy: Data(repeating: 0, count: 15))) { error in
            XCTAssertEqual(error as? SecureCryptoError, .invalidInput("Recovery entropy must be exactly 16 bytes."))
        }
    }

    private func keyData(_ key: SymmetricKey) -> Data {
        key.withUnsafeBytes { Data($0) }
    }
}
