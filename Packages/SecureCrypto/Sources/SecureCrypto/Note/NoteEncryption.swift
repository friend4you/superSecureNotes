import CryptoKit
import Foundation
import SecureCryptoProtocol

public func wrapFEK(_ fek: SymmetricKey, with udk: SymmetricKey) throws -> Data {
    try wrapKey(fek, with: udk)
}

public func unwrapFEK(_ wrappedFek: Data, with udk: SymmetricKey) throws -> SymmetricKey {
    try unwrapKey(wrappedFek, with: udk)
}

public func encryptPayload(_ payload: NotePayload, with fek: SymmetricKey) throws -> Data {
    let encoder = JSONEncoder()
    let plaintext: Data
    do {
        plaintext = try encoder.encode(payload)
    } catch {
        throw SecureCryptoError.decodingFailed("Failed to encode note payload as JSON.")
    }
    return try encrypt(plaintext, key: fek)
}

public func decryptPayload(_ encryptedPayload: Data, with fek: SymmetricKey) throws -> NotePayload {
    let plaintext = try decrypt(encryptedPayload, key: fek)
    let decoder = JSONDecoder()
    do {
        return try decoder.decode(NotePayload.self, from: plaintext)
    } catch {
        throw SecureCryptoError.decodingFailed("Failed to decode note payload JSON.")
    }
}
