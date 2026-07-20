import XCTest

@testable import SecureCryptoProtocol

final class AsymmetricKeyPairGeneratingTests: XCTestCase {
    func testMockReturns32ByteKeys() {
        let generator = MockAsymmetricKeyPairGenerator()
        let keyPair = generator.generateKeyPair()

        XCTAssertEqual(keyPair.publicKey.count, 32)
        XCTAssertEqual(keyPair.privateKey.count, 32)
    }
}

private struct MockAsymmetricKeyPairGenerator: AsymmetricKeyPairGenerating {
    func generateKeyPair() -> (publicKey: Data, privateKey: Data) {
        (
            publicKey: Data(repeating: 0x01, count: 32),
            privateKey: Data(repeating: 0x02, count: 32)
        )
    }
}
