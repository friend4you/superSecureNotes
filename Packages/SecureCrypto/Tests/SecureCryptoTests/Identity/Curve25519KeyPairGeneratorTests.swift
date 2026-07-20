import CryptoKit
import XCTest

@testable import SecureCrypto

final class Curve25519KeyPairGeneratorTests: XCTestCase {
    func testReturns32ByteKeys() {
        let generator = Curve25519KeyPairGenerator()
        let keyPair = generator.generateKeyPair()

        XCTAssertEqual(keyPair.publicKey.count, 32)
        XCTAssertEqual(keyPair.privateKey.count, 32)
    }

    func testKeyPairsAreUnique() {
        let generator = Curve25519KeyPairGenerator()
        let first = generator.generateKeyPair()
        let second = generator.generateKeyPair()

        XCTAssertNotEqual(first.publicKey, second.publicKey)
        XCTAssertNotEqual(first.privateKey, second.privateKey)
    }

    func testPublicKeyDerivableFromPrivateKey() throws {
        let generator = Curve25519KeyPairGenerator()
        let keyPair = generator.generateKeyPair()

        let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: keyPair.privateKey)
        XCTAssertEqual(privateKey.publicKey.rawRepresentation, keyPair.publicKey)
    }
}
