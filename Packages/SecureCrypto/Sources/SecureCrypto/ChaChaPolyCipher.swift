import CryptoKit
import Foundation

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
