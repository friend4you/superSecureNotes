import CryptoKit
import Foundation

public func wrapKey(_ key: SymmetricKey, with wrappingKey: SymmetricKey) throws -> Data {
    let keyBytes = key.withUnsafeBytes { Data($0) }
    return try encrypt(keyBytes, key: wrappingKey)
}

public func unwrapKey(_ wrapped: Data, with wrappingKey: SymmetricKey) throws -> SymmetricKey {
    let keyBytes = try decrypt(wrapped, key: wrappingKey)
    guard keyBytes.count == 32 else {
        throw SecureCryptoError.decodingFailed("Wrapped key material must be 32 bytes.")
    }
    return SymmetricKey(data: keyBytes)
}
