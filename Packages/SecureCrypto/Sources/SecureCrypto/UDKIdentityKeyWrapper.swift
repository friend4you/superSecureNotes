import CryptoKit
import Foundation
import SecureCryptoProtocol

public struct UDKIdentityKeyWrapper: IdentityKeyWrapping {
    private let cipher: SymmetricCipher

    public init(cipher: SymmetricCipher = ChaChaPolyCipher()) {
        self.cipher = cipher
    }

    public func wrapPrivateKey(_ privateKey: Data, with wrappingKey: SymmetricKey) throws -> Data {
        guard privateKey.count == Curve25519KeyPairGenerator.privateKeyLength else {
            throw SecureCryptoError.invalidInput(
                "Identity private key must be exactly \(Curve25519KeyPairGenerator.privateKeyLength) bytes."
            )
        }
        return try cipher.encrypt(privateKey, key: wrappingKey)
    }

    public func unwrapPrivateKey(_ wrapped: Data, with wrappingKey: SymmetricKey) throws -> Data {
        let privateKey = try cipher.decrypt(wrapped, key: wrappingKey)
        guard privateKey.count == Curve25519KeyPairGenerator.privateKeyLength else {
            throw SecureCryptoError.decodingFailed(
                "Identity private key material must be \(Curve25519KeyPairGenerator.privateKeyLength) bytes."
            )
        }
        return privateKey
    }
}

private let defaultIdentityKeyWrapper = UDKIdentityKeyWrapper()

public func wrapIdentityPrivateKey(_ privateKey: Data, with udk: SymmetricKey) throws -> Data {
    try defaultIdentityKeyWrapper.wrapPrivateKey(privateKey, with: udk)
}

public func unwrapIdentityPrivateKey(_ wrapped: Data, with udk: SymmetricKey) throws -> Data {
    try defaultIdentityKeyWrapper.unwrapPrivateKey(wrapped, with: udk)
}
