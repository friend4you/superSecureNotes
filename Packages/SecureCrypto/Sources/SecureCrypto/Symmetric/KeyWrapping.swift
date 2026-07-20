import CryptoKit
import Foundation
import SecureCryptoProtocol

public struct ChaChaPolyKeyWrapper: KeyWrapping {
    private let cipher: SymmetricCipher

    public init(cipher: SymmetricCipher = ChaChaPolyCipher()) {
        self.cipher = cipher
    }

    public func wrapKey(_ key: SymmetricKey, with wrappingKey: SymmetricKey) throws -> Data {
        let keyBytes = key.withUnsafeBytes { Data($0) }
        return try cipher.encrypt(keyBytes, key: wrappingKey)
    }

    public func unwrapKey(_ wrapped: Data, with wrappingKey: SymmetricKey) throws -> SymmetricKey {
        let keyBytes = try cipher.decrypt(wrapped, key: wrappingKey)
        guard keyBytes.count == 32 else {
            throw SecureCryptoError.decodingFailed("Wrapped key material must be 32 bytes.")
        }
        return SymmetricKey(data: keyBytes)
    }
}

private let defaultKeyWrapper = ChaChaPolyKeyWrapper()

public func wrapKey(_ key: SymmetricKey, with wrappingKey: SymmetricKey) throws -> Data {
    try defaultKeyWrapper.wrapKey(key, with: wrappingKey)
}

public func unwrapKey(_ wrapped: Data, with wrappingKey: SymmetricKey) throws -> SymmetricKey {
    try defaultKeyWrapper.unwrapKey(wrapped, with: wrappingKey)
}
