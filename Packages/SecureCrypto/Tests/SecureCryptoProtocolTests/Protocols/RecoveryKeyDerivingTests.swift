import CryptoKit
import XCTest

@testable import SecureCryptoProtocol

final class RecoveryKeyDerivingTests: XCTestCase {
    func testMockConformingTypeSatisfiesContract() throws {
        let deriver = MockRecoveryKeyDeriver()
        let entropy = Data(repeating: 0xAB, count: 16)

        let key = try deriver.deriveKey(entropy: entropy)
        XCTAssertEqual(key.bitCount, 256)
        XCTAssertEqual(keyData(key), entropy + entropy)
    }

    private func keyData(_ key: SymmetricKey) -> Data {
        key.withUnsafeBytes { Data($0) }
    }
}

private struct MockRecoveryKeyDeriver: RecoveryKeyDeriving {
    func deriveKey(entropy: Data) throws -> SymmetricKey {
        SymmetricKey(data: entropy + entropy)
    }
}
