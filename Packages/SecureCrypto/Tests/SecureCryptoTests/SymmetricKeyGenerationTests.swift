import CryptoKit
import XCTest

@testable import SecureCrypto

final class SymmetricKeyGenerationTests: XCTestCase {
    func testGenerateSymmetricKeyReturns256BitKey() {
        let key = generateSymmetricKey()

        XCTAssertEqual(key.bitCount, 256)
    }

    func testGenerateSymmetricKeyProducesDistinctValues() {
        let first = generateSymmetricKey()
        let second = generateSymmetricKey()

        XCTAssertNotEqual(keyData(first), keyData(second))
    }

    private func keyData(_ key: SymmetricKey) -> Data {
        key.withUnsafeBytes { Data($0) }
    }
}
