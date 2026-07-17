import CryptoKit
import Foundation

public protocol RecoveryKeyDeriving: Sendable {
    func deriveKey(entropy: Data) throws -> SymmetricKey
}

public struct HKDFRecoveryKeyDeriver: RecoveryKeyDeriving {
    public static let entropyLength = 16
    private static let info = Data("superSecureNotes.recovery".utf8)

    public init() {}

    public func deriveKey(entropy: Data) throws -> SymmetricKey {
        guard entropy.count == Self.entropyLength else {
            throw SecureCryptoError.invalidInput("Recovery entropy must be exactly 16 bytes.")
        }

        let inputKeyMaterial = SymmetricKey(data: entropy)
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKeyMaterial,
            salt: Data(),
            info: Self.info,
            outputByteCount: 32
        )
    }
}
