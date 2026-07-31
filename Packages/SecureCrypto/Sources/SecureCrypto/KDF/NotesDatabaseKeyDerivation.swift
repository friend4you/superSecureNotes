import CryptoKit
import Foundation

public func deriveNotesDatabaseKey(from udk: SymmetricKey) -> Data {
    let derivedKey = HKDF<SHA256>.deriveKey(
        inputKeyMaterial: udk,
        salt: Data(),
        info: Data("superSecureNotes.notes.db.v1".utf8),
        outputByteCount: 32
    )
    return derivedKey.withUnsafeBytes { Data($0) }
}
