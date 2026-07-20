import CryptoKit
import XCTest

@testable import SecureCryptoProtocol

final class IdentityKeyWrappingTests: XCTestCase {
    func testMockWrapUnwrapRoundtrip() throws {
        let wrapper = MockIdentityKeyWrapper()
        let udk = SymmetricKey(size: .bits256)
        let privateKey = Data(repeating: 0xAB, count: 32)

        let wrapped = try wrapper.wrapPrivateKey(privateKey, with: udk)
        let unwrapped = try wrapper.unwrapPrivateKey(wrapped, with: udk)

        XCTAssertEqual(unwrapped, privateKey)
    }

    func testMockWrongKeyFailsUnwrap() throws {
        let wrapper = MockIdentityKeyWrapper()
        let udk = SymmetricKey(size: .bits256)
        let wrongUDK = SymmetricKey(size: .bits256)
        let privateKey = Data(repeating: 0xAB, count: 32)

        let wrapped = try wrapper.wrapPrivateKey(privateKey, with: udk)

        XCTAssertThrowsError(try wrapper.unwrapPrivateKey(wrapped, with: wrongUDK)) { error in
            XCTAssertEqual(error as? SecureCryptoError, .authenticationFailed)
        }
    }
}

private struct MockIdentityKeyWrapper: IdentityKeyWrapping {
    private let cipher = ChaChaPolyMockCipher()

    func wrapPrivateKey(_ privateKey: Data, with wrappingKey: SymmetricKey) throws -> Data {
        try cipher.encrypt(privateKey, key: wrappingKey)
    }

    func unwrapPrivateKey(_ wrapped: Data, with wrappingKey: SymmetricKey) throws -> Data {
        try cipher.decrypt(wrapped, key: wrappingKey)
    }
}

private struct ChaChaPolyMockCipher: SymmetricCipher {
    func encrypt(_ plaintext: Data, key: SymmetricKey) throws -> Data {
        let nonce = ChaChaPoly.Nonce()
        let sealedBox = try ChaChaPoly.seal(plaintext, using: key, nonce: nonce)
        return sealedBox.combined
    }

    func decrypt(_ ciphertext: Data, key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try ChaChaPoly.SealedBox(combined: ciphertext)
            return try ChaChaPoly.open(sealedBox, using: key)
        } catch {
            throw SecureCryptoError.authenticationFailed
        }
    }
}
