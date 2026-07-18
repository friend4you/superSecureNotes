import CryptoKit
import XCTest

@testable import SecureCryptoProtocol

final class SymmetricKeyGeneratingTests: XCTestCase {
    func testMockReturns256BitKey() {
        let generator = MockSymmetricKeyGenerator()
        let key = generator.generateSymmetricKey()

        XCTAssertEqual(key.bitCount, 256)
    }
}

private struct MockSymmetricKeyGenerator: SymmetricKeyGenerating {
    func generateSymmetricKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }
}
