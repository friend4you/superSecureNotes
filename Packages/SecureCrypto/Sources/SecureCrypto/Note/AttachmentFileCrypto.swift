import CryptoKit
import Foundation

/// Encrypts raw attachment file bytes with the note FEK (ciphertext only, no extra envelope).
public func encryptAttachmentFile(_ plaintext: Data, with fek: SymmetricKey) throws -> Data {
    try encrypt(plaintext, key: fek)
}

/// Decrypts attachment ciphertext produced by `encryptAttachmentFile(_:with:)`.
public func decryptAttachmentFile(_ ciphertext: Data, with fek: SymmetricKey) throws -> Data {
    try decrypt(ciphertext, key: fek)
}
