import CryptoKit
import Foundation
import SecureCryptoProtocol

public struct Curve25519KeyPairGenerator: AsymmetricKeyPairGenerating {
    public static let algorithmID: UInt8 = 1
    public static let publicKeyLength = 32
    public static let privateKeyLength = 32

    public init() {}

    public func generateKeyPair() -> (publicKey: Data, privateKey: Data) {
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        return (
            publicKey: privateKey.publicKey.rawRepresentation,
            privateKey: privateKey.rawRepresentation
        )
    }
}

private let defaultKeyPairGenerator = Curve25519KeyPairGenerator()

public func generateIdentityKeyPair() -> (publicKey: Data, privateKey: Data) {
    defaultKeyPairGenerator.generateKeyPair()
}
