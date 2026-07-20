import CryptoKit
import Foundation
import SecureCryptoProtocol

public struct ChaChaPolyCipher: SymmetricCipher {
    public init() {}

    public func encrypt(_ plaintext: Data, key: SymmetricKey) throws -> Data {
        let nonce = ChaChaPoly.Nonce()
        let sealedBox = try ChaChaPoly.seal(plaintext, using: key, nonce: nonce)
        return sealedBox.combined
    }

    public func decrypt(_ ciphertext: Data, key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try ChaChaPoly.SealedBox(combined: ciphertext)
            return try ChaChaPoly.open(sealedBox, using: key)
        } catch {
            throw SecureCryptoError.authenticationFailed
        }
    }
}

private let defaultCipher = ChaChaPolyCipher()

public func encrypt(_ plaintext: Data, key: SymmetricKey) throws -> Data {
    try defaultCipher.encrypt(plaintext, key: key)
}

public func decrypt(_ ciphertext: Data, key: SymmetricKey) throws -> Data {
    try defaultCipher.decrypt(ciphertext, key: key)
}
